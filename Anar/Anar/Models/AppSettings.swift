import Foundation

enum RoutingMode: String, Codable, CaseIterable {
    case tun        // full system VPN (one-time helper install, no repeated prompts)
    case proxy      // system SOCKS/HTTP proxy

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
    var mode: RoutingMode = .tun
    var routingRule: RoutingRule = .bypassIran
    var adBlock: Bool = true
    var mixedPort: Int = 2080
    var clashApiPort: Int = 9090
    var logLevel: String = "info"
    var dnsServer: String = "tls://8.8.8.8"
    var autoConnectOnLaunch: Bool = false
    var accentColorName: String = "blue"

    static let logLevels = ["trace", "debug", "info", "warn", "error"]

    init() {}

    // Tolerant decoding: any missing key falls back to its default so adding
    // settings never invalidates a saved store.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func get<T: Decodable>(_ k: CodingKeys, _ def: T) -> T { (try? c.decode(T.self, forKey: k)) ?? def }
        mode = get(.mode, .tun)
        routingRule = get(.routingRule, .bypassIran)
        adBlock = get(.adBlock, true)
        mixedPort = get(.mixedPort, 2080)
        clashApiPort = get(.clashApiPort, 9090)
        logLevel = get(.logLevel, "info")
        dnsServer = get(.dnsServer, "tls://8.8.8.8")
        autoConnectOnLaunch = get(.autoConnectOnLaunch, false)
        accentColorName = get(.accentColorName, "blue")
    }
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
    var schemaVersion: Int = 0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profiles = (try? c.decode([ProxyProfile].self, forKey: .profiles)) ?? []
        subscriptions = (try? c.decode([Subscription].self, forKey: .subscriptions)) ?? []
        selectedId = (try? c.decodeIfPresent(String.self, forKey: .selectedId)) ?? nil
        settings = (try? c.decode(AppSettings.self, forKey: .settings)) ?? AppSettings()
        schemaVersion = (try? c.decode(Int.self, forKey: .schemaVersion)) ?? 0
    }
}
