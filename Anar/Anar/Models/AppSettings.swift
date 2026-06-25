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

/// How traffic is split between the tunnel and a direct connection.
enum RoutingRule: String, Codable, CaseIterable {
    case global       // everything through the proxy
    case bypassLAN    // only private/LAN addresses go direct
    case bypassIran   // Iran domains/IPs go direct (smart, recommended in Iran)

    var display: String {
        switch self {
        case .global: return "Global (all via proxy)"
        case .bypassLAN: return "Bypass LAN"
        case .bypassIran: return "Smart — Bypass Iran"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var mode: RoutingMode = .proxy
    var routingRule: RoutingRule = .bypassIran
    var adBlock: Bool = true
    var mixedPort: Int = 2080
    var clashApiPort: Int = 9090
    var logLevel: String = "info"
    var dnsServer: String = "tls://8.8.8.8"
    var autoConnectOnLaunch: Bool = false
    var accentColorName: String = "blue"

    static let logLevels = ["trace", "debug", "info", "warn", "error"]
}

/// A remote subscription that expands into many server profiles.
struct Subscription: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var name: String = ""
    var url: String = ""
    var lastUpdated: Date? = nil
}

struct AnarData: Codable {
    var profiles: [ProxyProfile] = []
    var subscriptions: [Subscription] = []
    var selectedId: String? = nil
    var settings: AppSettings = AppSettings()
}
