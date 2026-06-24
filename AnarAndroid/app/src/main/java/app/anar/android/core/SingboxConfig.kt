package app.anar.android.core

import org.json.JSONArray
import org.json.JSONObject

/**
 * Generates a sing-box (v1.13) JSON config for libbox. Mirrors the macOS
 * generator, whose output was validated against a real sing-box build.
 */
object SingboxConfig {

    const val PROXY_TAG = "proxy"

    fun generate(profile: ProxyProfile, settings: AppSettings): String {
        val root = JSONObject()

        root.put("log", JSONObject().put("level", settings.logLevel).put("timestamp", true))

        // remote = through proxy, local = OS resolver (direct) for bootstrapping.
        val dnsServers = JSONArray()
            .put(dnsServer(settings.dnsServer))
            .put(JSONObject().put("type", "local").put("tag", "local"))
        root.put("dns", JSONObject().put("servers", dnsServers).put("strategy", "prefer_ipv4"))

        // TUN inbound — libbox provides the fd via the VpnService platform interface.
        val tun = JSONObject()
            .put("type", "tun")
            .put("tag", "tun-in")
            .put("address", JSONArray().put("172.18.0.1/30"))
            .put("auto_route", true)
            .put("strict_route", false)
            .put("stack", "gvisor")
        root.put("inbounds", JSONArray().put(tun))

        if (profile.type == ProxyType.WIREGUARD) {
            root.put("endpoints", JSONArray().put(wireguardEndpoint(profile)))
            root.put("outbounds", JSONArray().put(direct()))
        } else {
            root.put("outbounds", JSONArray().put(outbound(profile)).put(direct()))
        }

        val rules = JSONArray()
            .put(JSONObject().put("action", "sniff"))
            .put(JSONObject().put("protocol", "dns").put("action", "hijack-dns"))
        if (settings.bypassPrivate) {
            rules.put(JSONObject().put("ip_is_private", true).put("outbound", "direct"))
        }
        root.put("route", JSONObject()
            .put("rules", rules)
            .put("final", PROXY_TAG)
            .put("auto_detect_interface", true)
            .put("default_domain_resolver", "local"))

        root.put("experimental", JSONObject().put("clash_api",
            JSONObject().put("external_controller", "127.0.0.1:${settings.clashApiPort}")))

        return root.toString(2)
    }

    private fun direct() = JSONObject().put("type", "direct").put("tag", "direct")

    private fun dnsServer(spec: String): JSONObject {
        var type = "udp"
        var server = spec
        val idx = spec.indexOf("://")
        if (idx >= 0) {
            type = spec.substring(0, idx).lowercase()
            server = spec.substring(idx + 3)
        }
        if (type != "https") server.indexOf('/').takeIf { it >= 0 }?.let { server = server.substring(0, it) }
        return when (type) {
            "https", "h3" -> {
                val host = server.substringBefore('/')
                val path = if (server.contains('/')) "/" + server.substringAfter('/') else "/dns-query"
                JSONObject().put("type", type).put("tag", "remote").put("server", host)
                    .put("path", path).put("domain_resolver", "local")
            }
            "quic" -> JSONObject().put("type", "quic").put("tag", "remote").put("server", server)
            "tls" -> JSONObject().put("type", "tls").put("tag", "remote").put("server", server)
            else -> JSONObject().put("type", "udp").put("tag", "remote").put("server", server)
        }
    }

    private fun outbound(p: ProxyProfile): JSONObject {
        val o = JSONObject()
            .put("tag", PROXY_TAG)
            .put("server", p.server)
            .put("server_port", p.port)
        when (p.type) {
            ProxyType.VMESS -> {
                o.put("type", "vmess").put("uuid", p.uuid)
                    .put("security", p.encryption.ifEmpty { "auto" }).put("alter_id", p.alterId)
                mergeTransport(o, p); mergeTLS(o, p)
            }
            ProxyType.VLESS -> {
                o.put("type", "vless").put("uuid", p.uuid)
                if (p.flow.isNotEmpty()) o.put("flow", p.flow)
                mergeTransport(o, p); mergeTLS(o, p)
            }
            ProxyType.TROJAN -> {
                o.put("type", "trojan").put("password", p.password)
                mergeTransport(o, p); mergeTLS(o, p)
            }
            ProxyType.SHADOWSOCKS ->
                o.put("type", "shadowsocks").put("method", p.method).put("password", p.password)
            ProxyType.HYSTERIA2 -> {
                o.put("type", "hysteria2").put("password", p.password)
                if (p.obfs.isNotEmpty()) {
                    o.put("obfs", JSONObject().put("type", p.obfs).put("password", p.obfsPassword))
                }
                o.put("tls", tlsBlock(p))
            }
            ProxyType.TUIC -> {
                o.put("type", "tuic").put("uuid", p.uuid).put("password", p.password)
                    .put("congestion_control", p.congestionControl.ifEmpty { "bbr" })
                    .put("udp_relay_mode", p.udpRelayMode.ifEmpty { "native" })
                o.put("tls", tlsBlock(p))
            }
            ProxyType.SOCKS -> o.put("type", "socks")
            ProxyType.HTTP -> o.put("type", "http")
            ProxyType.WIREGUARD -> {} // handled via endpoint
        }
        return o
    }

    private fun wireguardEndpoint(p: ProxyProfile): JSONObject {
        val peer = JSONObject()
            .put("address", p.server)
            .put("port", p.port)
            .put("public_key", p.peerPublicKey)
            .put("allowed_ips", JSONArray().put("0.0.0.0/0").put("::/0"))
        if (p.preSharedKey.isNotEmpty()) peer.put("pre_shared_key", p.preSharedKey)
        if (p.reserved.isNotEmpty()) peer.put("reserved", JSONArray(p.reserved))
        val addresses = if (p.localAddresses.isEmpty()) listOf("172.16.0.2/32") else p.localAddresses
        return JSONObject()
            .put("type", "wireguard")
            .put("tag", PROXY_TAG)
            .put("address", JSONArray(addresses))
            .put("private_key", p.privateKey)
            .put("peers", JSONArray().put(peer))
    }

    private fun mergeTransport(o: JSONObject, p: ProxyProfile) {
        when (p.network) {
            "ws" -> {
                val t = JSONObject().put("type", "ws")
                if (p.path.isNotEmpty()) t.put("path", p.path)
                if (p.hostHeader.isNotEmpty()) t.put("headers", JSONObject().put("Host", p.hostHeader))
                o.put("transport", t)
            }
            "grpc" -> o.put("transport", JSONObject().put("type", "grpc").put("service_name", p.path))
            "http", "h2" -> {
                val t = JSONObject().put("type", "http")
                if (p.hostHeader.isNotEmpty()) t.put("host", JSONArray().put(p.hostHeader))
                if (p.path.isNotEmpty()) t.put("path", p.path)
                o.put("transport", t)
            }
        }
    }

    private fun mergeTLS(o: JSONObject, p: ProxyProfile) {
        if (p.tls || p.reality) o.put("tls", tlsBlock(p))
    }

    private fun tlsBlock(p: ProxyProfile): JSONObject {
        val tls = JSONObject().put("enabled", true)
        tls.put("server_name", p.sni.ifEmpty { p.server })
        if (p.insecure) tls.put("insecure", true)
        if (p.alpn.isNotEmpty()) tls.put("alpn", JSONArray(p.alpn))
        if (p.fingerprint.isNotEmpty()) {
            tls.put("utls", JSONObject().put("enabled", true).put("fingerprint", p.fingerprint))
        }
        if (p.reality) {
            tls.put("reality", JSONObject().put("enabled", true)
                .put("public_key", p.publicKey).put("short_id", p.shortId))
            if (p.fingerprint.isEmpty()) {
                tls.put("utls", JSONObject().put("enabled", true).put("fingerprint", "chrome"))
            }
        }
        return tls
    }
}
