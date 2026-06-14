import SwiftUI
import UIKit

// MARK: - CalSnap Design System
// A cohesive, modern visual language: soft surfaces, vivid energy gradients,
// generous spacing and a calm typographic rhythm. Adapts to light & dark.

enum Theme {

    // MARK: Palette
    // Brand identity built around a fresh lime→emerald energy gradient
    // with a warm coral accent reserved for calories.
    enum Palette {
        // Brand
        static let brand = Color(hex: 0x10D9A3)      // vivid emerald-mint
        static let brandDeep = Color(hex: 0x059669)
        static let brandSoft = Color(hex: 0x6EE7B7)

        // Aurora accent colors used behind the glass
        static let aurora1 = Color(hex: 0x2DD4BF)    // teal
        static let aurora2 = Color(hex: 0x38BDF8)    // sky
        static let aurora3 = Color(hex: 0xA3E635)    // lime
        static let aurora4 = Color(hex: 0xC084FC)    // violet

        // Calories / energy accent
        static let calorie = Color(hex: 0xFF6B6B)
        static let calorieSoft = Color(hex: 0xFFA07A)

        // Macro accents
        static let protein = Color(hex: 0x60A5FA)   // blue
        static let carbs   = Color(hex: 0xFBBF24)   // amber
        static let fat     = Color(hex: 0xC084FC)   // violet

        // Semantic
        static let success = Color(hex: 0x22C55E)
        static let warning = Color(hex: 0xF59E0B)
        static let danger  = Color(hex: 0xF87171)
    }

    /// Glass tint used for material card borders (bright edge highlight).
    static func glassBorder(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [Color.white.opacity(0.25), Color.white.opacity(0.05)]
                : [Color.white.opacity(0.9), Color.white.opacity(0.3)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    /// Subtle translucent fill for chips placed on top of glass cards.
    static func chipFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.55)
    }

    // MARK: Adaptive surfaces
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x0B1014) : Color(hex: 0xF6F8F7)
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x161D22) : Color.white
    }

    static func surfaceElevated(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x1E262C) : Color.white
    }

    static func separator(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.06)
    }

    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xF2F5F4) : Color(hex: 0x10211B)
    }

    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x9AA7A2) : Color(hex: 0x6B7A74)
    }

    // MARK: Gradients
    static let energyGradient = LinearGradient(
        colors: [Palette.brandSoft, Palette.brand, Palette.brandDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let calorieGradient = LinearGradient(
        colors: [Palette.calorieSoft, Palette.calorie],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static func heroGradient(_ scheme: ColorScheme) -> LinearGradient {
        scheme == .dark
        ? LinearGradient(colors: [Color(hex: 0x0E1A16), Color(hex: 0x0B1014)],
                         startPoint: .top, endPoint: .bottom)
        : LinearGradient(colors: [Color(hex: 0xE8FBF1), Color(hex: 0xF6F8F7)],
                         startPoint: .top, endPoint: .bottom)
    }

    // MARK: Metrics
    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 18
        static let lg: CGFloat = 26
        static let pill: CGFloat = 999
    }

    enum Space {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 32
    }

    // MARK: Typography
    enum Font {
        static func display(_ size: CGFloat = 34) -> SwiftUI.Font {
            .system(size: size, weight: .bold, design: .rounded)
        }
        static func title(_ size: CGFloat = 22) -> SwiftUI.Font {
            .system(size: size, weight: .semibold, design: .rounded)
        }
        static func body(_ size: CGFloat = 16) -> SwiftUI.Font {
            .system(size: size, weight: .regular, design: .rounded)
        }
        static func caption(_ size: CGFloat = 13) -> SwiftUI.Font {
            .system(size: size, weight: .medium, design: .rounded)
        }
        static func mono(_ size: CGFloat = 30) -> SwiftUI.Font {
            .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
        }
    }
}

// MARK: - Color helpers
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// Loads a named color from the asset catalog, falling back to a literal
    /// when the asset is missing so previews never crash.
    init(_ name: String, bundle: Bundle?, fallback: Color) {
        if UIColor(named: name, in: bundle, compatibleWith: nil) != nil {
            self.init(name, bundle: bundle)
        } else {
            self = fallback
        }
    }
}
