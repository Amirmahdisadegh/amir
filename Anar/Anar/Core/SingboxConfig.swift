import Foundation

/// Builds a sing-box (v1.13) JSON configuration for a selected profile.
enum SingboxConfig {

    static let proxyTag = "proxy"

    static func generate(profile: ProxyProfile, settings: AppSettings) throws -> Data {
        var root: [String: Any] = [:]

        root["log"] = ["level": settings.logLevel, "timestamp": true]

        // "remote" tunnels DNS through the proxy; "local" uses the OS resolver
        // (direct) and bootstraps the proxy server's own domain — this avoids the
        // resolve-loop without a forbidden detour-to-direct.
        root["dns"] = [
            "servers": [
                dnsServer(settings.dnsServer),
                ["type": "local", "tag": "local"],
            ],
            "strategy": "prefer_ipv4",
        ]

        // Inbound
        switch settings.mode {
        case .tun:
            root["inbounds"] = [[
                "type": "tun",
                "tag": "tun-in",
                "address": ["172.18.0.1/30"],
                "auto_route": true,
                "strict_route": true,
                "stack": "gvisor",
            ]]
        case .proxy:
            root["inbounds"] = [[
                "type": "mixed",
                "tag": "mixed-in",
                "listen": "127.0.0.1",
                "listen_port": settings.mixedPort,
            ]]
        }

        // Outbounds / endpoints
        if profile.type == .wireguard {
            root["endpoints"] = [wireguardEndpoint(profile)]
            root["outbounds"] = [["type": "direct", "tag": "direct"]]
        } else {
            root["outbounds"] = [try outbound(profile), ["type": "direct", "tag": "direct"]]
        }

        // Route
        var rules: [[String: Any]] = [
            ["action": "sniff"],
            ["protocol": "dns", "action": "hijack-dns"],
        ]
        var ruleSets: [[String: Any]] = []

        if settings.routingRule != .global {
            rules.append(["ip_is_private": true, "outbound": "direct"])
        }
        if settings.adBlock {
            ruleSets.append(remoteRuleSet("geosite-ads", "geosite-category-ads-all"))
            rules.append(["rule_set": ["geosite-ads"], "action": "reject"])
        }
        if settings.routingRule == .bypassIran {
            ruleSets.append(remoteRuleSet("geoip-ir", "geoip-ir"))
            ruleSets.append(remoteRuleSet("geosite-ir", "geosite-ir"))
            rules.append(["rule_set": ["geoip-ir", "geosite-ir"], "outbound": "direct"])
        }

        var route: [String: Any] = [
            "rules": rules,
            "final": proxyTag,
            "auto_detect_interface": true,
            "default_domain_resolver": "local",
        ]
        if !ruleSets.isEmpty { route["rule_set"] = ruleSets }
        root["route"] = route

        // Live stats API
        root["experimental"] = [
            "clash_api": [
                "external_controller": "127.0.0.1:\(settings.clashApiPort)",
            ],
        ]

        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    /// A remote .srs rule-set, downloaded through the proxy (reliable in Iran).
    private static func remoteRuleSet(_ tag: String, _ name: String) -> [String: Any] {
        [
            "type": "remote",
            "tag": tag,
            "format": "binary",
            "url": "https://raw.githubusercontent.com/Chocolate4U/Iran-sing-box-rules/rule-set/\(name).srs",
            "download_detour": proxyTag,
        ]
    }

    /// Builds a sing-box 1.12+ DNS server object from a "scheme://host" string.
    /// Examples: "tls://8.8.8.8", "https://dns.google/dns-query", "1.1.1.1".
    private static func dnsServer(_ spec: String) -> [String: Any] {
        var type = "udp"
        var server = spec
        if let r = spec.range(of: "://") {
            type = String(spec[..<r.lowerBound]).lowercased()
            server = String(spec[r.upperBound...])
        }
        // Keep only the host for tls/udp/quic; https keeps the full host.
        if type != "https", let slash = server.firstIndex(of: "/") {
            server = String(server[..<slash])
        }
        switch type {
        case "https": return ["type": "https", "tag": "remote", "server": serverHost(server), "path": serverPath(server), "domain_resolver": "local"]
        case "tls": return ["type": "tls", "tag": "remote", "server": server]
        case "quic": return ["type": "quic", "tag": "remote", "server": server]
        case "h3": return ["type": "h3", "tag": "remote", "server": serverHost(server), "path": serverPath(server), "domain_resolver": "local"]
        default: return ["type": "udp", "tag": "remote", "server": server]
        }
    }

    private static func serverHost(_ s: String) -> String {
        if let slash = s.firstIndex(of: "/") { return String(s[..<slash]) }
        return s
    }
    private static func serverPath(_ s: String) -> String {
        if let slash = s.firstIndex(of: "/") { return String(s[slash...]) }
        return "/dns-query"
    }

    // MARK: - Outbound builders

    private static func outbound(_ p: ProxyProfile) throws -> [String: Any] {
        var o: [String: Any] = [
            "tag": proxyTag,
            "server": p.server,
            "server_port": p.port,
        ]
        switch p.type {
        case .vmess:
            o["type"] = "vmess"
            o["uuid"] = p.uuid
            o["security"] = p.encryption.isEmpty ? "auto" : p.encryption
            o["alter_id"] = p.alterId
            mergeTransport(&o, p); mergeTLS(&o, p)
        case .vless:
            o["type"] = "vless"
            o["uuid"] = p.uuid
            if !p.flow.isEmpty { o["flow"] = p.flow }
            mergeTransport(&o, p); mergeTLS(&o, p)
        case .trojan:
            o["type"] = "trojan"
            o["password"] = p.password
            mergeTransport(&o, p); mergeTLS(&o, p)
        case .shadowsocks:
            o["type"] = "shadowsocks"
            o["method"] = p.method
            o["password"] = p.password
        case .hysteria2:
            o["type"] = "hysteria2"
            o["password"] = p.password
            if !p.obfs.isEmpty {
                o["obfs"] = ["type": p.obfs, "password": p.obfsPassword]
            }
            o["tls"] = tlsBlock(p, forceEnabled: true)
        case .tuic:
            o["type"] = "tuic"
            o["uuid"] = p.uuid
            o["password"] = p.password
            o["congestion_control"] = p.congestionControl.isEmpty ? "bbr" : p.congestionControl
            o["udp_relay_mode"] = p.udpRelayMode.isEmpty ? "native" : p.udpRelayMode
            o["tls"] = tlsBlock(p, forceEnabled: true)
        case .socks:
            o["type"] = "socks"
        case .http:
            o["type"] = "http"
        case .wireguard:
            throw SingboxError.handledAsEndpoint
        }
        return o
    }

    private static func wireguardEndpoint(_ p: ProxyProfile) -> [String: Any] {
        var peer: [String: Any] = [
            "address": p.server,
            "port": p.port,
            "public_key": p.peerPublicKey,
            "allowed_ips": ["0.0.0.0/0", "::/0"],
            "persistent_keepalive_interval": 25,
        ]
        if !p.preSharedKey.isEmpty { peer["pre_shared_key"] = p.preSharedKey }
        if !p.reserved.isEmpty { peer["reserved"] = p.reserved }
        return [
            "type": "wireguard",
            "tag": proxyTag,
            "mtu": 1408,
            "address": p.localAddresses.isEmpty ? ["172.16.0.2/32"] : p.localAddresses,
            "private_key": p.privateKey,
            "peers": [peer],
        ]
    }

    // MARK: - Shared blocks

    private static func mergeTransport(_ o: inout [String: Any], _ p: ProxyProfile) {
        switch p.network {
        case "ws":
            var t: [String: Any] = ["type": "ws"]
            if !p.path.isEmpty { t["path"] = p.path }
            if !p.hostHeader.isEmpty { t["headers"] = ["Host": p.hostHeader] }
            o["transport"] = t
        case "grpc":
            o["transport"] = ["type": "grpc", "service_name": p.path]
        case "http", "h2":
            var t: [String: Any] = ["type": "http"]
            if !p.hostHeader.isEmpty { t["host"] = [p.hostHeader] }
            if !p.path.isEmpty { t["path"] = p.path }
            o["transport"] = t
        default:
            break // tcp: no transport block
        }
    }

    private static func mergeTLS(_ o: inout [String: Any], _ p: ProxyProfile) {
        guard p.tls || p.reality else { return }
        o["tls"] = tlsBlock(p, forceEnabled: true)
    }

    private static func tlsBlock(_ p: ProxyProfile, forceEnabled: Bool) -> [String: Any] {
        var tls: [String: Any] = ["enabled": true]
        let serverName = p.sni.isEmpty ? p.server : p.sni
        tls["server_name"] = serverName
        if p.insecure { tls["insecure"] = true }
        if !p.alpn.isEmpty { tls["alpn"] = p.alpn }
        if !p.fingerprint.isEmpty {
            tls["utls"] = ["enabled": true, "fingerprint": p.fingerprint]
        }
        if p.reality {
            tls["reality"] = [
                "enabled": true,
                "public_key": p.publicKey,
                "short_id": p.shortId,
            ]
            // REALITY requires uTLS; default to chrome if none specified.
            if p.fingerprint.isEmpty {
                tls["utls"] = ["enabled": true, "fingerprint": "chrome"]
            }
        }
        return tls
    }

    enum SingboxError: Error { case handledAsEndpoint }
}
