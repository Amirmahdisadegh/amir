import Foundation

/// Parses proxy share links (vmess://, vless://, trojan://, ss://, hysteria2://,
/// tuic://, wireguard://) into ProxyProfile values. Lenient by design — real
/// links in the wild vary a lot.
enum LinkParser {

    enum ParseError: LocalizedError {
        case empty
        case unsupported(String)
        case malformed(String)

        var errorDescription: String? {
            switch self {
            case .empty: return "Empty link."
            case .unsupported(let s): return "Unsupported link type: \(s)"
            case .malformed(let s): return "Malformed link (\(s))."
            }
        }
    }

    // MARK: - Entry points

    /// Parses one link. Throws on failure.
    static func parse(_ raw: String) throws -> ProxyProfile {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let scheme = text.components(separatedBy: "://").first?.lowercased(),
              text.contains("://") else { throw ParseError.empty }

        switch scheme {
        case "vmess": return try parseVMess(text)
        case "vless": return try parseStandard(text, type: .vless)
        case "trojan": return try parseStandard(text, type: .trojan)
        case "ss": return try parseShadowsocks(text)
        case "hysteria2", "hy2": return try parseStandard(text, type: .hysteria2)
        case "tuic": return try parseStandard(text, type: .tuic)
        case "wireguard", "wg": return try parseWireGuard(text)
        default: throw ParseError.unsupported(scheme)
        }
    }

    /// Parses many links from subscription content: raw newline list or a single
    /// base64 blob containing newline-separated links. Skips lines it can't parse.
    static func parseMany(_ content: String) -> [ProxyProfile] {
        var body = content.trimmingCharacters(in: .whitespacesAndNewlines)
        // A subscription body is often base64-encoded as a whole.
        if !body.contains("://"), let decoded = decodeBase64(body) {
            body = decoded
        }
        var out: [ProxyProfile] = []
        for line in body.split(whereSeparator: \.isNewline) {
            let s = line.trimmingCharacters(in: .whitespaces)
            guard s.contains("://") else { continue }
            if let p = try? parse(s) { out.append(p) }
        }
        return out
    }

    // MARK: - VMess

    private static func parseVMess(_ text: String) throws -> ProxyProfile {
        let payload = String(text.dropFirst("vmess://".count))
        guard let data = decodeBase64(payload)?.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw ParseError.malformed("vmess base64/json") }

        func s(_ k: String) -> String { string(obj[k]) }
        func i(_ k: String) -> Int { intValue(obj[k]) ?? 0 }

        var p = ProxyProfile(type: .vmess)
        p.name = s("ps").isEmpty ? s("add") : s("ps")
        p.server = s("add")
        p.port = i("port")
        p.uuid = s("id")
        p.alterId = i("aid")
        p.encryption = s("scy").isEmpty ? "auto" : s("scy")
        p.network = s("net").isEmpty ? "tcp" : s("net")
        p.path = s("path")
        p.hostHeader = s("host")
        let tls = s("tls")
        p.tls = (tls == "tls" || tls == "reality")
        p.sni = s("sni").isEmpty ? p.hostHeader : s("sni")
        p.fingerprint = s("fp")
        if !s("alpn").isEmpty { p.alpn = s("alpn").components(separatedBy: ",").filter { !$0.isEmpty } }
        if p.network == "grpc", !s("path").isEmpty { p.path = s("path") }
        return p
    }

    // MARK: - VLESS / Trojan / Hysteria2 / TUIC (URI form)

    private static func parseStandard(_ text: String, type: ProxyType) throws -> ProxyProfile {
        guard let parts = URIParts(text) else { throw ParseError.malformed("\(type.display) uri") }

        var p = ProxyProfile(type: type)
        p.server = parts.host
        p.port = parts.port
        p.name = parts.fragment.isEmpty ? parts.host : parts.fragment
        let q = parts.query

        switch type {
        case .vless:
            p.uuid = parts.user
            p.flow = q["flow"] ?? ""
            p.encryption = q["encryption"] ?? "none"
        case .trojan:
            p.password = parts.user
        case .hysteria2:
            p.password = parts.user
            p.obfs = q["obfs"] ?? ""
            p.obfsPassword = q["obfs-password"] ?? ""
        case .tuic:
            // tuic://uuid:password@host:port
            let creds = parts.user.components(separatedBy: ":")
            p.uuid = creds.first ?? ""
            p.password = creds.count > 1 ? creds.dropFirst().joined(separator: ":") : ""
            p.congestionControl = q["congestion_control"] ?? q["congestion"] ?? ""
            p.udpRelayMode = q["udp_relay_mode"] ?? ""
        default: break
        }

        // Transport (shared by vless/trojan)
        p.network = q["type"] ?? "tcp"
        if p.network == "grpc" {
            p.path = q["serviceName"] ?? q["servicename"] ?? ""
        } else {
            p.path = q["path"] ?? ""
            p.hostHeader = q["host"] ?? ""
        }

        // TLS / REALITY
        let security = (q["security"] ?? "").lowercased()
        p.tls = (security == "tls" || security == "reality" || type == .hysteria2 || type == .tuic)
        p.reality = (security == "reality")
        p.sni = q["sni"] ?? q["peer"] ?? p.hostHeader
        p.fingerprint = q["fp"] ?? ""
        p.insecure = (q["allowInsecure"] == "1" || q["insecure"] == "1")
        if let alpn = q["alpn"], !alpn.isEmpty {
            p.alpn = alpn.components(separatedBy: ",").filter { !$0.isEmpty }
        }
        if p.reality {
            p.publicKey = q["pbk"] ?? ""
            p.shortId = q["sid"] ?? ""
        }
        return p
    }

    // MARK: - Shadowsocks

    private static func parseShadowsocks(_ text: String) throws -> ProxyProfile {
        var body = String(text.dropFirst("ss://".count))
        var name = ""
        if let hashIdx = body.firstIndex(of: "#") {
            name = percentDecode(String(body[body.index(after: hashIdx)...]))
            body = String(body[..<hashIdx])
        }
        // Strip query (e.g. ?plugin=...) — plugins are not supported in v1.
        if let qIdx = body.firstIndex(of: "?") { body = String(body[..<qIdx]) }

        var p = ProxyProfile(type: .shadowsocks)

        if let atIdx = body.lastIndex(of: "@") {
            // SIP002: base64url(method:password)@host:port
            let userinfo = String(body[..<atIdx])
            let hostport = String(body[body.index(after: atIdx)...])
            let creds = decodeBase64(userinfo) ?? userinfo
            let cp = creds.components(separatedBy: ":")
            p.method = cp.first ?? ""
            p.password = cp.count > 1 ? cp.dropFirst().joined(separator: ":") : ""
            guard let hp = splitHostPort(hostport) else { throw ParseError.malformed("ss host:port") }
            p.server = hp.0; p.port = hp.1
        } else {
            // Legacy: base64(method:password@host:port)
            guard let decoded = decodeBase64(body) else { throw ParseError.malformed("ss base64") }
            guard let atIdx = decoded.lastIndex(of: "@") else { throw ParseError.malformed("ss legacy") }
            let creds = String(decoded[..<atIdx]).components(separatedBy: ":")
            p.method = creds.first ?? ""
            p.password = creds.count > 1 ? creds.dropFirst().joined(separator: ":") : ""
            guard let hp = splitHostPort(String(decoded[decoded.index(after: atIdx)...])) else {
                throw ParseError.malformed("ss legacy host:port")
            }
            p.server = hp.0; p.port = hp.1
        }
        p.name = name.isEmpty ? p.server : name
        return p
    }

    // MARK: - WireGuard (best-effort)

    private static func parseWireGuard(_ text: String) throws -> ProxyProfile {
        guard let parts = URIParts(text) else { throw ParseError.malformed("wireguard uri") }
        var p = ProxyProfile(type: .wireguard)
        p.server = parts.host
        p.port = parts.port
        p.name = parts.fragment.isEmpty ? parts.host : parts.fragment
        p.privateKey = percentDecode(parts.user)
        let q = parts.query
        p.peerPublicKey = q["publickey"] ?? q["public_key"] ?? q["peer_public_key"] ?? ""
        p.preSharedKey = q["presharedkey"] ?? q["pre_shared_key"] ?? ""
        if let addr = q["address"] ?? q["ip"] {
            p.localAddresses = addr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        if let res = q["reserved"] {
            p.reserved = res.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        return p
    }

    // MARK: - Helpers

    /// Lightweight URI splitter: scheme://user@host:port?query#fragment
    private struct URIParts {
        var user = ""
        var host = ""
        var port = 443
        var query: [String: String] = [:]
        var fragment = ""

        init?(_ text: String) {
            guard let range = text.range(of: "://") else { return nil }
            var rest = String(text[range.upperBound...])

            if let hashIdx = rest.firstIndex(of: "#") {
                fragment = percentDecode(String(rest[rest.index(after: hashIdx)...]))
                rest = String(rest[..<hashIdx])
            }
            if let qIdx = rest.firstIndex(of: "?") {
                let qs = String(rest[rest.index(after: qIdx)...])
                rest = String(rest[..<qIdx])
                for pair in qs.split(separator: "&") {
                    let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
                    if kv.count == 2 { query[kv[0].lowercased()] = percentDecode(kv[1]) }
                    else if kv.count == 1 { query[kv[0].lowercased()] = "" }
                }
            }
            if let atIdx = rest.lastIndex(of: "@") {
                user = String(rest[..<atIdx])
                rest = String(rest[rest.index(after: atIdx)...])
            }
            guard let hp = LinkParser.splitHostPort(rest) else { return nil }
            host = hp.0; port = hp.1
        }
    }

    static func splitHostPort(_ s: String) -> (String, Int)? {
        var str = s
        // IPv6 in brackets: [::1]:443
        if str.hasPrefix("["), let close = str.firstIndex(of: "]") {
            let host = String(str[str.index(after: str.startIndex)..<close])
            let after = String(str[str.index(after: close)...])
            let port = after.hasPrefix(":") ? Int(after.dropFirst()) ?? 443 : 443
            return (host, port)
        }
        if let colon = str.lastIndex(of: ":") {
            let host = String(str[..<colon])
            let port = Int(str[str.index(after: colon)...]) ?? 443
            if !host.isEmpty { return (host, port) }
        }
        return str.isEmpty ? nil : (str, 443)
    }

    private static func string(_ any: Any?) -> String {
        if let s = any as? String { return s }
        if let n = any as? NSNumber { return n.stringValue }
        return ""
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let n = any as? NSNumber { return n.intValue }
        if let s = any as? String { return Int(s) }
        return nil
    }

    private static func percentDecode(_ s: String) -> String {
        s.removingPercentEncoding ?? s
    }

    /// Decodes standard or URL-safe base64, with or without padding.
    static func decodeBase64(_ s: String) -> String? {
        var b64 = s.replacingOccurrences(of: "-", with: "+")
                   .replacingOccurrences(of: "_", with: "/")
                   .trimmingCharacters(in: .whitespacesAndNewlines)
        let rem = b64.count % 4
        if rem > 0 { b64.append(String(repeating: "=", count: 4 - rem)) }
        guard let data = Data(base64Encoded: b64) ?? Data(base64Encoded: s) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
