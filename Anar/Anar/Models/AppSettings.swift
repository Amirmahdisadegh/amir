import Foundation

enum RoutingMode: String, Codable, CaseIterable {
    case tun        // full system VPN (needs admin)
    case proxy      // system SOCKS/HTTP proxy (no admin)

    var display: String {
        switch self {
        case .tun: return "TUN (Full VPN)"
        case .proxy: return "System Proxy"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var mode: RoutingMode = .proxy
    var mixedPort: Int = 2080          // local SOCKS/HTTP listener (proxy mode)
    var clashApiPort: Int = 9090       // sing-box Clash API for live stats
    var logLevel: String = "info"
    var bypassPrivate: Bool = true     // route LAN/private IPs directly
    var dnsServer: String = "tls://8.8.8.8"
    var autoConnectOnLaunch: Bool = false

    static let logLevels = ["trace", "debug", "info", "warn", "error"]
}

struct AnarData: Codable {
    var profiles: [ProxyProfile] = []
    var selectedId: String? = nil
    var settings: AppSettings = AppSettings()
    var subscriptionURL: String = ""
}
