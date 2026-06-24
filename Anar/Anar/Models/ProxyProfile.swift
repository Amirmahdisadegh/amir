import Foundation

enum ProxyType: String, Codable, CaseIterable {
    case vmess, vless, trojan, shadowsocks, hysteria2, tuic, wireguard, socks, http

    var display: String {
        switch self {
        case .vmess: return "VMess"
        case .vless: return "VLESS"
        case .trojan: return "Trojan"
        case .shadowsocks: return "Shadowsocks"
        case .hysteria2: return "Hysteria2"
        case .tuic: return "TUIC"
        case .wireguard: return "WireGuard"
        case .socks: return "SOCKS"
        case .http: return "HTTP"
        }
    }
}

/// A single proxy server. Holds the superset of fields used across all
/// supported protocols; the sing-box config generator reads only what each
/// type needs.
struct ProxyProfile: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var name: String = ""
    var type: ProxyType = .vless
    var server: String = ""
    var port: Int = 443

    // Credentials
    var uuid: String = ""          // vmess / vless / tuic
    var password: String = ""      // trojan / shadowsocks / hysteria2 / tuic
    var method: String = ""        // shadowsocks cipher
    var alterId: Int = 0           // vmess
    var encryption: String = "auto" // vmess "scy" cipher
    var flow: String = ""          // vless flow (e.g. xtls-rprx-vision)

    // Transport
    var network: String = "tcp"    // tcp / ws / grpc / http
    var path: String = ""          // ws/http path, or grpc serviceName
    var hostHeader: String = ""    // ws/http Host header

    // TLS
    var tls: Bool = false
    var sni: String = ""
    var alpn: [String] = []
    var insecure: Bool = false
    var fingerprint: String = ""   // uTLS fingerprint, e.g. chrome

    // REALITY
    var reality: Bool = false
    var publicKey: String = ""     // pbk
    var shortId: String = ""       // sid

    // WireGuard
    var privateKey: String = ""
    var peerPublicKey: String = ""
    var preSharedKey: String = ""
    var localAddresses: [String] = []
    var reserved: [Int] = []

    // Hysteria2 / TUIC extras
    var obfs: String = ""
    var obfsPassword: String = ""
    var congestionControl: String = "" // tuic: bbr / cubic
    var udpRelayMode: String = ""       // tuic: native / quic

    var subtitle: String {
        "\(type.display) · \(server):\(port)"
    }

    var isValid: Bool {
        guard !server.isEmpty, port > 0 else { return false }
        switch type {
        case .vmess, .vless, .tuic: return !uuid.isEmpty
        case .trojan, .hysteria2: return !password.isEmpty
        case .shadowsocks: return !password.isEmpty && !method.isEmpty
        case .wireguard: return !privateKey.isEmpty && !peerPublicKey.isEmpty
        case .socks, .http: return true
        }
    }
}
