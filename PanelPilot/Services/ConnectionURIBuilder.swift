import Foundation

/// Builds shareable VLESS / VMess connection URIs from an inbound's stream settings
/// plus a client's UUID and the server address.
enum ConnectionURIBuilder {

    /// Build a connection URI for the given client on the given inbound.
    static func uri(for client: Client, inbound: Inbound, serverAddress: String) -> String {
        switch inbound.`protocol`.lowercased() {
        case "vless":
            return vless(client: client, inbound: inbound, address: serverAddress)
        case "vmess":
            return vmess(client: client, inbound: inbound, address: serverAddress)
        default:
            return vless(client: client, inbound: inbound, address: serverAddress)
        }
    }

    // MARK: - VLESS

    private static func vless(client: Client, inbound: Inbound, address: String) -> String {
        let stream = inbound.stream
        var params: [String: String] = [
            "type": stream.network,
            "encryption": "none"
        ]

        switch stream.security.lowercased() {
        case "reality":
            params["security"] = "reality"
            if let r = stream.reality {
                params["pbk"] = r.publicKey
                params["sni"] = r.primaryServerName
                if !r.primaryShortId.isEmpty { params["sid"] = r.primaryShortId }
                params["fp"] = r.fingerprint.isEmpty ? "chrome" : r.fingerprint
                if !r.spiderX.isEmpty { params["spx"] = r.spiderX }
            }
            if !client.flow.isEmpty { params["flow"] = client.flow }
        case "tls":
            params["security"] = "tls"
            if let sni = stream.tlsServerName, !sni.isEmpty { params["sni"] = sni }
            if !client.flow.isEmpty { params["flow"] = client.flow }
        default:
            params["security"] = "none"
        }

        applyTransport(stream: stream, into: &params)

        let query = params
            .filter { !$0.value.isEmpty }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(percentEncode($0.value))" }
            .joined(separator: "&")

        let fragment = percentEncode(fragmentLabel(remark: inbound.remark, email: client.email))
        return "vless://\(client.id)@\(address):\(inbound.port)?\(query)#\(fragment)"
    }

    // MARK: - VMess (base64 JSON form)

    private static func vmess(client: Client, inbound: Inbound, address: String) -> String {
        let stream = inbound.stream
        var dict: [String: Any] = [
            "v": "2",
            "ps": fragmentLabel(remark: inbound.remark, email: client.email),
            "add": address,
            "port": String(inbound.port),
            "id": client.id,
            "aid": "0",
            "scy": "auto",
            "net": stream.network,
            "type": stream.tcpHeaderType ?? "none",
            "tls": stream.security.lowercased() == "tls" ? "tls" : ""
        ]
        if stream.network == "ws" {
            dict["path"] = stream.wsPath ?? "/"
            dict["host"] = stream.wsHost ?? ""
        }
        if let sni = stream.tlsServerName, !sni.isEmpty { dict["sni"] = sni }

        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let b64 = String(data: data, encoding: .utf8)?
                .data(using: .utf8)?.base64EncodedString() else {
            return ""
        }
        return "vmess://\(b64)"
    }

    // MARK: - Helpers

    private static func applyTransport(stream: StreamSettings, into params: inout [String: String]) {
        switch stream.network {
        case "ws":
            if let path = stream.wsPath { params["path"] = path }
            if let host = stream.wsHost, !host.isEmpty { params["host"] = host }
        case "tcp":
            if let header = stream.tcpHeaderType, header != "none" {
                params["headerType"] = header
            }
        default:
            break
        }
    }

    private static func fragmentLabel(remark: String, email: String) -> String {
        let r = remark.isEmpty ? "PanelPilot" : remark
        return email.isEmpty ? r : "\(r)-\(email)"
    }

    private static func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
