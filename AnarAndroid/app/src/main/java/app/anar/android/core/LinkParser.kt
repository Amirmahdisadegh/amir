package app.anar.android.core

import android.util.Base64
import org.json.JSONObject
import java.net.URLDecoder

/** Parses proxy share links into ProxyProfile. Ported from the macOS client. */
object LinkParser {

    class ParseException(message: String) : Exception(message)

    fun parse(raw: String): ProxyProfile {
        val text = raw.trim()
        if (!text.contains("://")) throw ParseException("Not a proxy link")
        return when (text.substringBefore("://").lowercase()) {
            "vmess" -> parseVMess(text)
            "vless" -> parseStandard(text, ProxyType.VLESS)
            "trojan" -> parseStandard(text, ProxyType.TROJAN)
            "ss" -> parseShadowsocks(text)
            "hysteria2", "hy2" -> parseStandard(text, ProxyType.HYSTERIA2)
            "tuic" -> parseStandard(text, ProxyType.TUIC)
            "wireguard", "wg" -> parseWireGuard(text)
            else -> throw ParseException("Unsupported link type")
        }
    }

    /** Parses many links from raw or base64 subscription content. */
    fun parseMany(content: String): List<ProxyProfile> {
        var body = content.trim()
        if (!body.contains("://")) {
            decodeBase64(body)?.let { body = it }
        }
        return body.lineSequence()
            .map { it.trim() }
            .filter { it.contains("://") }
            .mapNotNull { runCatching { parse(it) }.getOrNull() }
            .toList()
    }

    // VMess: base64(JSON)
    private fun parseVMess(text: String): ProxyProfile {
        val payload = text.removePrefix("vmess://")
        val json = decodeBase64(payload) ?: throw ParseException("Bad vmess base64")
        val o = JSONObject(json)
        fun s(k: String) = o.opt(k)?.toString() ?: ""
        fun i(k: String) = o.opt(k)?.toString()?.toIntOrNull() ?: 0
        return ProxyProfile(type = ProxyType.VMESS).apply {
            name = s("ps").ifEmpty { s("add") }
            server = s("add")
            port = i("port")
            uuid = s("id")
            alterId = i("aid")
            encryption = s("scy").ifEmpty { "auto" }
            network = s("net").ifEmpty { "tcp" }
            path = s("path")
            hostHeader = s("host")
            val t = s("tls")
            tls = (t == "tls" || t == "reality")
            sni = s("sni").ifEmpty { hostHeader }
            fingerprint = s("fp")
            if (s("alpn").isNotEmpty()) alpn = s("alpn").split(",").filter { it.isNotEmpty() }
        }
    }

    // VLESS / Trojan / Hysteria2 / TUIC URI form
    private fun parseStandard(text: String, type: ProxyType): ProxyProfile {
        val u = Uri(text)
        val p = ProxyProfile(type = type)
        p.server = u.host
        p.port = u.port
        p.name = u.fragment.ifEmpty { u.host }
        val q = u.query

        when (type) {
            ProxyType.VLESS -> {
                p.uuid = u.user
                p.flow = q["flow"] ?: ""
                p.encryption = q["encryption"] ?: "none"
            }
            ProxyType.TROJAN -> p.password = u.user
            ProxyType.HYSTERIA2 -> {
                p.password = u.user
                p.obfs = q["obfs"] ?: ""
                p.obfsPassword = q["obfs-password"] ?: ""
            }
            ProxyType.TUIC -> {
                val creds = u.user.split(":")
                p.uuid = creds.getOrElse(0) { "" }
                p.password = if (creds.size > 1) creds.drop(1).joinToString(":") else ""
                p.congestionControl = q["congestion_control"] ?: q["congestion"] ?: ""
                p.udpRelayMode = q["udp_relay_mode"] ?: ""
            }
            else -> {}
        }

        p.network = q["type"] ?: "tcp"
        if (p.network == "grpc") {
            p.path = q["serviceName"] ?: q["servicename"] ?: ""
        } else {
            p.path = q["path"] ?: ""
            p.hostHeader = q["host"] ?: ""
        }

        val security = (q["security"] ?: "").lowercase()
        p.tls = security == "tls" || security == "reality" ||
                type == ProxyType.HYSTERIA2 || type == ProxyType.TUIC
        p.reality = security == "reality"
        p.sni = q["sni"] ?: q["peer"] ?: p.hostHeader
        p.fingerprint = q["fp"] ?: ""
        p.insecure = q["allowInsecure"] == "1" || q["insecure"] == "1"
        q["alpn"]?.takeIf { it.isNotEmpty() }?.let { p.alpn = it.split(",").filter { s -> s.isNotEmpty() } }
        if (p.reality) {
            p.publicKey = q["pbk"] ?: ""
            p.shortId = q["sid"] ?: ""
        }
        return p
    }

    private fun parseShadowsocks(text: String): ProxyProfile {
        var body = text.removePrefix("ss://")
        var name = ""
        body.indexOf('#').takeIf { it >= 0 }?.let {
            name = urlDecode(body.substring(it + 1))
            body = body.substring(0, it)
        }
        body.indexOf('?').takeIf { it >= 0 }?.let { body = body.substring(0, it) }

        val p = ProxyProfile(type = ProxyType.SHADOWSOCKS)
        val at = body.lastIndexOf('@')
        if (at >= 0) {
            val userinfo = body.substring(0, at)
            val hostport = body.substring(at + 1)
            val creds = (decodeBase64(userinfo) ?: userinfo).split(":")
            p.method = creds.getOrElse(0) { "" }
            p.password = if (creds.size > 1) creds.drop(1).joinToString(":") else ""
            val hp = splitHostPort(hostport) ?: throw ParseException("ss host:port")
            p.server = hp.first; p.port = hp.second
        } else {
            val decoded = decodeBase64(body) ?: throw ParseException("ss base64")
            val a = decoded.lastIndexOf('@')
            if (a < 0) throw ParseException("ss legacy")
            val creds = decoded.substring(0, a).split(":")
            p.method = creds.getOrElse(0) { "" }
            p.password = if (creds.size > 1) creds.drop(1).joinToString(":") else ""
            val hp = splitHostPort(decoded.substring(a + 1)) ?: throw ParseException("ss legacy host:port")
            p.server = hp.first; p.port = hp.second
        }
        p.name = name.ifEmpty { p.server }
        return p
    }

    private fun parseWireGuard(text: String): ProxyProfile {
        val u = Uri(text)
        val p = ProxyProfile(type = ProxyType.WIREGUARD)
        p.server = u.host
        p.port = u.port
        p.name = u.fragment.ifEmpty { u.host }
        p.privateKey = urlDecode(u.user)
        val q = u.query
        p.peerPublicKey = q["publickey"] ?: q["public_key"] ?: q["peer_public_key"] ?: ""
        p.preSharedKey = q["presharedkey"] ?: q["pre_shared_key"] ?: ""
        (q["address"] ?: q["ip"])?.let { p.localAddresses = it.split(",").map { s -> s.trim() } }
        q["reserved"]?.let { p.reserved = it.split(",").mapNotNull { s -> s.trim().toIntOrNull() } }
        return p
    }

    // Lightweight URI: scheme://user@host:port?query#fragment
    private class Uri(text: String) {
        var user = ""
        var host = ""
        var port = 443
        val query = HashMap<String, String>()
        var fragment = ""

        init {
            var rest = text.substringAfter("://")
            rest.indexOf('#').takeIf { it >= 0 }?.let {
                fragment = urlDecode(rest.substring(it + 1))
                rest = rest.substring(0, it)
            }
            rest.indexOf('?').takeIf { it >= 0 }?.let {
                val qs = rest.substring(it + 1)
                rest = rest.substring(0, it)
                for (pair in qs.split("&")) {
                    val kv = pair.split("=", limit = 2)
                    if (kv.size == 2) query[kv[0].lowercase()] = urlDecode(kv[1])
                    else if (kv.size == 1 && kv[0].isNotEmpty()) query[kv[0].lowercase()] = ""
                }
            }
            rest.lastIndexOf('@').takeIf { it >= 0 }?.let {
                user = rest.substring(0, it)
                rest = rest.substring(it + 1)
            }
            val hp = splitHostPort(rest) ?: throw ParseException("bad host:port")
            host = hp.first; port = hp.second
        }
    }

    private fun splitHostPort(s: String): Pair<String, Int>? {
        if (s.startsWith("[")) {
            val close = s.indexOf(']')
            if (close > 0) {
                val host = s.substring(1, close)
                val after = s.substring(close + 1)
                val port = if (after.startsWith(":")) after.drop(1).toIntOrNull() ?: 443 else 443
                return host to port
            }
        }
        val colon = s.lastIndexOf(':')
        if (colon > 0) {
            val host = s.substring(0, colon)
            val port = s.substring(colon + 1).toIntOrNull() ?: 443
            if (host.isNotEmpty()) return host to port
        }
        return if (s.isEmpty()) null else s to 443
    }

    private fun urlDecode(s: String): String =
        runCatching { URLDecoder.decode(s, "UTF-8") }.getOrDefault(s)

    fun decodeBase64(s: String): String? {
        val cleaned = s.replace("-", "+").replace("_", "/").trim()
        for (flags in intArrayOf(Base64.DEFAULT, Base64.NO_PADDING or Base64.NO_WRAP)) {
            runCatching {
                val bytes = Base64.decode(cleaned, flags)
                return String(bytes, Charsets.UTF_8)
            }
        }
        return null
    }
}
