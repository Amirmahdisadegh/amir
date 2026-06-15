import SwiftUI
import UIKit

// MARK: - User-customizable appearance

/// An accent colour preset (drives the brand colour + aurora blobs).
struct AccentPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let brand: Color
    let brandSoft: Color
    let brandDeep: Color
    let aurora: [Color]   // exactly 4

    static let presets: [AccentPreset] = [
        AccentPreset(id: "blue", name: "Electric Blue",
                     brand: Color(hex: 0x2E9CFF), brandSoft: Color(hex: 0x7CC4FF), brandDeep: Color(hex: 0x1D6FD6),
                     aurora: [Color(hex: 0x22D3EE), Color(hex: 0x3B82F6), Color(hex: 0x6366F1), Color(hex: 0x0EA5E9)]),
        AccentPreset(id: "violet", name: "Iris",
                     brand: Color(hex: 0x8B5CF6), brandSoft: Color(hex: 0xC4B5FD), brandDeep: Color(hex: 0x6D28D9),
                     aurora: [Color(hex: 0xA78BFA), Color(hex: 0x6366F1), Color(hex: 0xEC4899), Color(hex: 0x38BDF8)]),
        AccentPreset(id: "pink", name: "Magenta",
                     brand: Color(hex: 0xF45D9E), brandSoft: Color(hex: 0xFBA5CE), brandDeep: Color(hex: 0xC2348B),
                     aurora: [Color(hex: 0xF472B6), Color(hex: 0xA855F7), Color(hex: 0xFB7185), Color(hex: 0x818CF8)]),
        AccentPreset(id: "orange", name: "Sunset",
                     brand: Color(hex: 0xFF7A4D), brandSoft: Color(hex: 0xFFB088), brandDeep: Color(hex: 0xE0552C),
                     aurora: [Color(hex: 0xFB7185), Color(hex: 0xF59E0B), Color(hex: 0xF472B6), Color(hex: 0xFDBA74)]),
        AccentPreset(id: "teal", name: "Aqua",
                     brand: Color(hex: 0x2DD4BF), brandSoft: Color(hex: 0x7FE9DC), brandDeep: Color(hex: 0x0D9488),
                     aurora: [Color(hex: 0x22D3EE), Color(hex: 0x2DD4BF), Color(hex: 0x38BDF8), Color(hex: 0x34D399)]),
        AccentPreset(id: "crimson", name: "Crimson",
                     brand: Color(hex: 0xF43F5E), brandSoft: Color(hex: 0xFB8DA0), brandDeep: Color(hex: 0xBE123C),
                     aurora: [Color(hex: 0xF43F5E), Color(hex: 0xEC4899), Color(hex: 0xF97316), Color(hex: 0xA855F7)]),
        AccentPreset(id: "lime", name: "Lime",
                     brand: Color(hex: 0x84CC16), brandSoft: Color(hex: 0xBEF264), brandDeep: Color(hex: 0x4D7C0F),
                     aurora: [Color(hex: 0xA3E635), Color(hex: 0x22C55E), Color(hex: 0xFACC15), Color(hex: 0x2DD4BF)]),
        AccentPreset(id: "gold", name: "Gold",
                     brand: Color(hex: 0xF5B301), brandSoft: Color(hex: 0xFCD34D), brandDeep: Color(hex: 0xCA8A04),
                     aurora: [Color(hex: 0xFACC15), Color(hex: 0xF59E0B), Color(hex: 0xFB923C), Color(hex: 0xEAB308)]),
    ]

    static func by(id: String) -> AccentPreset {
        presets.first { $0.id == id } ?? presets[0]
    }

    /// Builds a full preset from a single custom colour.
    static func custom(_ base: Color) -> AccentPreset {
        AccentPreset(
            id: "custom", name: "Custom",
            brand: base,
            brandSoft: base.adjusted(brightness: 0.16, saturation: -0.08),
            brandDeep: base.adjusted(brightness: -0.22),
            aurora: [base,
                     base.adjusted(brightness: 0.12),
                     base.adjusted(hue: 0.07),
                     base.adjusted(hue: -0.07)]
        )
    }
}

extension Color {
    /// Returns a copy with HSB components nudged (clamped to valid ranges).
    func adjusted(brightness db: CGFloat = 0, saturation ds: CGFloat = 0, hue dh: CGFloat = 0) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        func clamp(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }
        return Color(hue: Double(clamp(h + dh)),
                     saturation: Double(clamp(s + ds)),
                     brightness: Double(clamp(b + db)),
                     opacity: Double(a))
    }

    /// 0xRRGGBB representation.
    var hexValue: UInt {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (UInt(clamp255(r)) << 16) | (UInt(clamp255(g)) << 8) | UInt(clamp255(b))
    }
    private func clamp255(_ v: CGFloat) -> Int { min(max(Int(v * 255), 0), 255) }
}

/// Background treatment behind the glass.
enum BackgroundStyle: String, CaseIterable, Identifiable {
    case aurora     // colourful animated blobs (default)
    case black      // pure black (OLED)
    case graphite   // flat graphite, minimal
    case vivid      // bolder, more saturated blobs
    case photo      // a user-chosen photo

    var id: String { rawValue }
    var name: String {
        switch self {
        case .aurora:   return "Aurora"
        case .black:    return "Pure Black"
        case .graphite: return "Graphite"
        case .vivid:    return "Vivid"
        case .photo:    return "Photo"
        }
    }
}

// MARK: - Live appearance state (set by AppState, read by the Theme)

extension Theme {
    /// Current accent colours. Mutating this and rebuilding the view tree updates the UI.
    static var accent: AccentPreset = AccentPreset.presets[0]
    /// 0 = nearly solid panels, 1 = maximum translucency.
    static var glassIntensity: Double = 0.6
    /// Background treatment.
    static var backgroundStyle: BackgroundStyle = .aurora
    /// User-chosen background photo (when backgroundStyle == .photo).
    static var backgroundImage: UIImage?
}

/// Persists the optional custom accent colour and background photo.
enum AppearanceStore {
    private static var photoURL: URL {
        URL.applicationSupportDirectory.appending(path: "calsnap-bg.jpg")
    }

    static func saveBackgroundPhoto(_ image: UIImage?) {
        guard let image, let data = image.jpegData(compressionQuality: 0.85) else {
            try? FileManager.default.removeItem(at: photoURL)
            return
        }
        try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory,
                                                 withIntermediateDirectories: true)
        try? data.write(to: photoURL)
    }

    static func loadBackgroundPhoto() -> UIImage? {
        guard let data = try? Data(contentsOf: photoURL) else { return nil }
        return UIImage(data: data)
    }
}
