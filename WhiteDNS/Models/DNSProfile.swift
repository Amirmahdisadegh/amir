import Foundation

enum DNSProtocol: String, Codable, CaseIterable, Identifiable {
    case udp  = "DNS"
    case doh  = "DoH"
    case dot  = "DoT"
    var id: String { rawValue }
}

struct DNSProfile: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var primary: String
    var secondary: String
    var proto: DNSProtocol
    var dohURL: String
    var dotHost: String
    var isBuiltin: Bool
    var colorHex: String

    init(id: UUID = .init(), name: String, primary: String, secondary: String = "",
         proto: DNSProtocol = .udp, dohURL: String = "", dotHost: String = "",
         isBuiltin: Bool = false, colorHex: String = "7C6FEA") {
        self.id = id; self.name = name; self.primary = primary
        self.secondary = secondary; self.proto = proto
        self.dohURL = dohURL; self.dotHost = dotHost
        self.isBuiltin = isBuiltin; self.colorHex = colorHex
    }

    var servers: [String] { [primary, secondary].filter { !$0.isEmpty } }

    static let builtin: [DNSProfile] = [
        DNSProfile(name: "Cloudflare",  primary: "1.1.1.1",        secondary: "1.0.0.1",         proto: .doh, dohURL: "https://cloudflare-dns.com/dns-query", isBuiltin: true, colorHex: "F6821F"),
        DNSProfile(name: "Google",      primary: "8.8.8.8",        secondary: "8.8.4.4",         proto: .doh, dohURL: "https://dns.google/dns-query",          isBuiltin: true, colorHex: "4285F4"),
        DNSProfile(name: "Quad9",       primary: "9.9.9.9",        secondary: "149.112.112.112", proto: .doh, dohURL: "https://dns.quad9.net/dns-query",        isBuiltin: true, colorHex: "7C3AED"),
        DNSProfile(name: "AdGuard",     primary: "94.140.14.14",   secondary: "94.140.15.15",    proto: .doh, dohURL: "https://dns.adguard.com/dns-query",      isBuiltin: true, colorHex: "67AC5B"),
        DNSProfile(name: "Shecan",      primary: "178.22.122.100", secondary: "185.51.200.2",    proto: .udp, isBuiltin: true, colorHex: "10B981"),
        DNSProfile(name: "403.online",  primary: "10.202.10.202",  secondary: "10.202.10.10",    proto: .udp, isBuiltin: true, colorHex: "EF4444"),
        DNSProfile(name: "Electro",     primary: "78.157.42.101",  secondary: "78.157.42.100",   proto: .udp, isBuiltin: true, colorHex: "0EA5E9"),
        DNSProfile(name: "NextDNS",     primary: "45.90.28.0",     secondary: "45.90.30.0",      proto: .doh, dohURL: "https://dns.nextdns.io/dns-query",        isBuiltin: true, colorHex: "3B82F6"),
    ]
}
