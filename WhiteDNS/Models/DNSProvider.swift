import Foundation
import SwiftUI

enum DNSProtocolType: String, Codable, CaseIterable {
    case standard = "DNS"
    case doh = "DoH"
    case dot = "DoT"
}

struct DNSProvider: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var servers: [String]
    var colorHex: String
    var description: String
    var isCustom: Bool
    var dohURL: String?
    var dotHostname: String?

    init(id: UUID = UUID(), name: String, servers: [String], colorHex: String,
         description: String, isCustom: Bool = false, dohURL: String? = nil, dotHostname: String? = nil) {
        self.id = id
        self.name = name
        self.servers = servers
        self.colorHex = colorHex
        self.description = description
        self.isCustom = isCustom
        self.dohURL = dohURL
        self.dotHostname = dotHostname
    }

    var color: Color { Color(hex: colorHex) ?? .blue }

    var protocolType: DNSProtocolType {
        if dohURL != nil { return .doh }
        if dotHostname != nil { return .dot }
        return .standard
    }

    var primaryServer: String { servers.first ?? "—" }
    var secondaryServer: String? { servers.count > 1 ? servers[1] : nil }

    static let presets: [DNSProvider] = [
        DNSProvider(
            name: "Cloudflare",
            servers: ["1.1.1.1", "1.0.0.1"],
            colorHex: "F6821F",
            description: "سریع‌ترین DNS دنیا · حریم خصوصی",
            dohURL: "https://cloudflare-dns.com/dns-query"
        ),
        DNSProvider(
            name: "Google",
            servers: ["8.8.8.8", "8.8.4.4"],
            colorHex: "4285F4",
            description: "پایدار و قابل اعتماد",
            dohURL: "https://dns.google/dns-query"
        ),
        DNSProvider(
            name: "Quad9",
            servers: ["9.9.9.9", "149.112.112.112"],
            colorHex: "7C3AED",
            description: "مسدودسازی بدافزار · امنیت محور",
            dohURL: "https://dns.quad9.net/dns-query"
        ),
        DNSProvider(
            name: "AdGuard",
            servers: ["94.140.14.14", "94.140.15.15"],
            colorHex: "67AC5B",
            description: "مسدودسازی تبلیغات و ترکر",
            dohURL: "https://dns.adguard.com/dns-query"
        ),
        DNSProvider(
            name: "Shecan",
            servers: ["178.22.122.100", "185.51.200.2"],
            colorHex: "10B981",
            description: "رفع محدودیت سایت‌های خارجی در ایران"
        ),
        DNSProvider(
            name: "403.online",
            servers: ["10.202.10.202", "10.202.10.10"],
            colorHex: "EF4444",
            description: "رفع خطای ۴۰۳ و محدودیت"
        ),
        DNSProvider(
            name: "Electro",
            servers: ["78.157.42.101", "78.157.42.100"],
            colorHex: "0EA5E9",
            description: "رفع محدودیت اینترنت ایران"
        ),
        DNSProvider(
            name: "NextDNS",
            servers: ["45.90.28.0", "45.90.30.0"],
            colorHex: "3B82F6",
            description: "DNS قابل تنظیم شخصی",
            dohURL: "https://dns.nextdns.io/dns-query"
        ),
    ]
}
