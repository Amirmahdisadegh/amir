import SwiftData
import SwiftUI

// MARK: - Billing Cycle

enum BillingCycle: String, Codable, CaseIterable {
    case weekly    = "هفتگی"
    case biweekly  = "دو هفته‌ای"
    case monthly   = "ماهانه"
    case quarterly = "سه‌ماهه"
    case biannual  = "شش‌ماهه"
    case yearly    = "سالانه"

    var intervalDays: Int {
        switch self {
        case .weekly:    return 7
        case .biweekly:  return 14
        case .monthly:   return 30
        case .quarterly: return 90
        case .biannual:  return 180
        case .yearly:    return 365
        }
    }

    var shortLabel: String {
        switch self {
        case .weekly:    return "هفتگی"
        case .biweekly:  return "دو هفته"
        case .monthly:   return "ماهانه"
        case .quarterly: return "سه‌ماهه"
        case .biannual:  return "شش‌ماهه"
        case .yearly:    return "سالانه"
        }
    }
}

// MARK: - Known Subscription Services

struct KnownService: Identifiable, Hashable {
    let id: String
    let name: String
    let sfSymbol: String
    let colorHex: String
    let category: ServiceCategory

    var color: Color {
        Color(hex: colorHex) ?? .appPrimary
    }

    enum ServiceCategory: String, CaseIterable {
        case video       = "ویدیو"
        case music       = "موسیقی"
        case gaming      = "بازی"
        case productivity = "بهره‌وری"
        case cloud       = "فضای ابری"
        case news        = "خبر و کتاب"
        case iranian     = "ایرانی"
        case other       = "سایر"

        var icon: String {
            switch self {
            case .video:       return "play.rectangle.fill"
            case .music:       return "music.note"
            case .gaming:      return "gamecontroller.fill"
            case .productivity: return "briefcase.fill"
            case .cloud:       return "icloud.fill"
            case .news:        return "newspaper.fill"
            case .iranian:     return "flag.fill"
            case .other:       return "ellipsis.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .video:       return .red
            case .music:       return .green
            case .gaming:      return .blue
            case .productivity: return .orange
            case .cloud:       return .cyan
            case .news:        return .indigo
            case .iranian:     return Color(hex: "#16a34a") ?? .green
            case .other:       return .gray
            }
        }
    }

    static let all: [KnownService] = [
        // 📺 Video
        KnownService(id: "netflix",    name: "Netflix",          sfSymbol: "play.rectangle.fill",          colorHex: "#E50914", category: .video),
        KnownService(id: "youtube",    name: "YouTube Premium",  sfSymbol: "play.circle.fill",              colorHex: "#FF0000", category: .video),
        KnownService(id: "disney",     name: "Disney+",          sfSymbol: "star.circle.fill",              colorHex: "#113CCF", category: .video),
        KnownService(id: "appletv",    name: "Apple TV+",        sfSymbol: "appletv.fill",                  colorHex: "#1c1c1e", category: .video),
        KnownService(id: "max",        name: "Max (HBO)",         sfSymbol: "tv.circle.fill",                colorHex: "#5F26BD", category: .video),
        KnownService(id: "amazon",     name: "Prime Video",       sfSymbol: "video.circle.fill",             colorHex: "#00A8E1", category: .video),
        KnownService(id: "hulu",       name: "Hulu",             sfSymbol: "play.tv.fill",                  colorHex: "#1CE783", category: .video),
        KnownService(id: "paramount",  name: "Paramount+",       sfSymbol: "mountain.2.circle.fill",        colorHex: "#0064FF", category: .video),
        KnownService(id: "peacock",    name: "Peacock",          sfSymbol: "bird.fill",                     colorHex: "#000000", category: .video),
        KnownService(id: "crunchyroll",name: "Crunchyroll",      sfSymbol: "c.circle.fill",                 colorHex: "#FF6B1A", category: .video),

        // 🎵 Music
        KnownService(id: "spotify",    name: "Spotify",          sfSymbol: "music.note.list",               colorHex: "#1DB954", category: .music),
        KnownService(id: "applemusic", name: "Apple Music",      sfSymbol: "music.note.circle.fill",        colorHex: "#FA2D48", category: .music),
        KnownService(id: "ytmusic",    name: "YouTube Music",    sfSymbol: "headphones.circle.fill",        colorHex: "#FF0000", category: .music),
        KnownService(id: "tidal",      name: "Tidal",            sfSymbol: "waveform.circle.fill",          colorHex: "#0D0D0D", category: .music),
        KnownService(id: "deezer",     name: "Deezer",           sfSymbol: "music.quarternote.3",           colorHex: "#EF3F6B", category: .music),
        KnownService(id: "soundcloud", name: "SoundCloud",       sfSymbol: "cloud.fill",                    colorHex: "#FF5500", category: .music),
        KnownService(id: "amazonmusic",name: "Amazon Music",     sfSymbol: "music.mic.circle.fill",         colorHex: "#00A8E1", category: .music),

        // 🎮 Gaming
        KnownService(id: "applearcade",name: "Apple Arcade",     sfSymbol: "gamecontroller.fill",           colorHex: "#0071E3", category: .gaming),
        KnownService(id: "xboxpass",   name: "Xbox Game Pass",   sfSymbol: "xmark.circle.fill",             colorHex: "#107C10", category: .gaming),
        KnownService(id: "psplus",     name: "PlayStation Plus", sfSymbol: "p.circle.fill",                 colorHex: "#003087", category: .gaming),
        KnownService(id: "eaplay",     name: "EA Play",          sfSymbol: "sportscourt.fill",              colorHex: "#FF4747", category: .gaming),
        KnownService(id: "nintendo",   name: "Nintendo Online",  sfSymbol: "n.circle.fill",                 colorHex: "#E4000F", category: .gaming),
        KnownService(id: "steam",      name: "Steam",            sfSymbol: "desktopcomputer",               colorHex: "#1B2838", category: .gaming),

        // 💼 Productivity & Cloud
        KnownService(id: "appleone",   name: "Apple One",        sfSymbol: "apple.logo",                    colorHex: "#888888", category: .cloud),
        KnownService(id: "icloud",     name: "iCloud+",          sfSymbol: "icloud.fill",                   colorHex: "#0071E3", category: .cloud),
        KnownService(id: "googleone",  name: "Google One",       sfSymbol: "g.circle.fill",                 colorHex: "#4285F4", category: .cloud),
        KnownService(id: "ms365",      name: "Microsoft 365",    sfSymbol: "doc.circle.fill",               colorHex: "#0078D4", category: .productivity),
        KnownService(id: "adobe",      name: "Adobe CC",         sfSymbol: "a.circle.fill",                 colorHex: "#FA0F00", category: .productivity),
        KnownService(id: "notion",     name: "Notion",           sfSymbol: "square.grid.2x2.fill",          colorHex: "#000000", category: .productivity),
        KnownService(id: "chatgpt",    name: "ChatGPT Plus",     sfSymbol: "bubble.left.and.bubble.right.fill", colorHex: "#10A37F", category: .productivity),
        KnownService(id: "claude",     name: "Claude Pro",       sfSymbol: "brain",                         colorHex: "#D97706", category: .productivity),
        KnownService(id: "dropbox",    name: "Dropbox",          sfSymbol: "archivebox.fill",               colorHex: "#0061FF", category: .cloud),
        KnownService(id: "figma",      name: "Figma",            sfSymbol: "paintpalette.fill",             colorHex: "#F24E1E", category: .productivity),

        // 📰 News & Reading
        KnownService(id: "applenews",  name: "Apple News+",      sfSymbol: "newspaper.fill",                colorHex: "#FA2D48", category: .news),
        KnownService(id: "kindle",     name: "Kindle Unlimited", sfSymbol: "book.circle.fill",              colorHex: "#FF9900", category: .news),
        KnownService(id: "medium",     name: "Medium",           sfSymbol: "m.circle.fill",                 colorHex: "#000000", category: .news),

        // 🇮🇷 Iranian
        KnownService(id: "filimo",     name: "فیلیمو",          sfSymbol: "film.circle.fill",              colorHex: "#CC0000", category: .iranian),
        KnownService(id: "namava",     name: "نماوا",            sfSymbol: "sparkles.tv.fill",              colorHex: "#1976D2", category: .iranian),
        KnownService(id: "aparat",     name: "آپارات",           sfSymbol: "play.square.fill",              colorHex: "#E84C22", category: .iranian),
        KnownService(id: "telewebion", name: "تله‌وبیون",        sfSymbol: "antenna.radiowaves.left.and.right", colorHex: "#0288D1", category: .iranian),
        KnownService(id: "fidibo",     name: "فیدیبو",           sfSymbol: "books.vertical.circle.fill",    colorHex: "#D84315", category: .iranian),
        KnownService(id: "taghche",    name: "طاقچه",            sfSymbol: "book.fill",                     colorHex: "#6D4C41", category: .iranian),
        KnownService(id: "cafebazaar", name: "کافه بازار",       sfSymbol: "cup.and.saucer.fill",           colorHex: "#2E7D32", category: .iranian),
        KnownService(id: "myket",      name: "مایکت",            sfSymbol: "m.square.fill",                 colorHex: "#1565C0", category: .iranian),
        KnownService(id: "tamasha",    name: "تماشا",            sfSymbol: "tv.circle.fill",                colorHex: "#388E3C", category: .iranian),
        KnownService(id: "viovi",      name: "ویووی",            sfSymbol: "play.circle.fill",              colorHex: "#4527A0", category: .iranian),
        KnownService(id: "snapp",      name: "اسنپ",             sfSymbol: "car.circle.fill",               colorHex: "#F9A800", category: .iranian),
    ]

    static func find(id serviceId: String) -> KnownService? {
        all.first { $0.id == serviceId }
    }
}

// MARK: - Color from Hex

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }
}

// MARK: - SwiftData Model

@Model
final class SubscriptionRecord {
    var id: UUID
    var serviceId: String
    var serviceName: String
    var customName: String
    var amount: Double
    var currency: String
    var billingCycleRaw: String
    var startDate: Date
    var nextRenewalDate: Date
    var isActive: Bool
    var notes: String
    var notifyBeforeDays: Int
    var isTrial: Bool
    var trialEndDate: Date?
    var paymentMethod: String
    var autoRenew: Bool

    var billingCycle: BillingCycle {
        get { BillingCycle(rawValue: billingCycleRaw) ?? .monthly }
        set { billingCycleRaw = newValue.rawValue }
    }

    var displayName: String { customName.isEmpty ? serviceName : customName }
    var knownService: KnownService? { KnownService.find(id: serviceId) }
    var serviceColor: Color { knownService?.color ?? .appPrimary }
    var serviceIcon: String { knownService?.sfSymbol ?? "creditcard.fill" }

    var daysUntilRenewal: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                         to: Calendar.current.startOfDay(for: nextRenewalDate)).day ?? 0
    }

    var isRenewalSoon: Bool { (0...7).contains(daysUntilRenewal) }
    var isOverdue: Bool { daysUntilRenewal < 0 }

    var monthlyEquivalent: Double {
        switch billingCycle {
        case .weekly:    return amount * 4.33
        case .biweekly:  return amount * 2.17
        case .monthly:   return amount
        case .quarterly: return amount / 3.0
        case .biannual:  return amount / 6.0
        case .yearly:    return amount / 12.0
        }
    }

    func scheduleNextRenewal() {
        nextRenewalDate = Calendar.current.date(
            byAdding: .day, value: billingCycle.intervalDays, to: nextRenewalDate
        ) ?? nextRenewalDate
    }

    init(
        serviceId: String = "",
        serviceName: String,
        customName: String = "",
        amount: Double,
        currency: String = "IRR",
        billingCycle: BillingCycle = .monthly,
        startDate: Date = Date(),
        notifyBeforeDays: Int = 3,
        paymentMethod: String = "کارت بانکی",
        autoRenew: Bool = true
    ) {
        self.id = UUID()
        self.serviceId = serviceId
        self.serviceName = serviceName
        self.customName = customName
        self.amount = amount
        self.currency = currency
        self.billingCycleRaw = billingCycle.rawValue
        self.startDate = startDate
        self.nextRenewalDate = Calendar.current.date(
            byAdding: .day, value: billingCycle.intervalDays, to: startDate) ?? startDate
        self.isActive = true
        self.notes = ""
        self.notifyBeforeDays = notifyBeforeDays
        self.isTrial = false
        self.trialEndDate = nil
        self.paymentMethod = paymentMethod
        self.autoRenew = autoRenew
    }
}
