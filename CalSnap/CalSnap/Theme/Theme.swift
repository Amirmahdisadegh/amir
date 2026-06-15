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
        // Brand — driven by the user-selected accent preset (Theme.accent)
        static var brand: Color { Theme.accent.brand }
        static var brandDeep: Color { Theme.accent.brandDeep }
        static var brandSoft: Color { Theme.accent.brandSoft }

        // Aurora accent colors come from the selected preset
        static var aurora1: Color { Theme.accent.aurora[0] }
        static var aurora2: Color { Theme.accent.aurora[1] }
        static var aurora3: Color { Theme.accent.aurora[2] }
        static var aurora4: Color { Theme.accent.aurora[3] }

        // Calories / energy accent — warm orange contrasts the cool theme
        static let calorie = Color(hex: 0xFF8A5B)
        static let calorieSoft = Color(hex: 0xFFB088)

        // Macro accents
        static let protein = Color(hex: 0x38BDF8)   // sky blue
        static let carbs   = Color(hex: 0xFBBF24)   // amber
        static let fat     = Color(hex: 0xA78BFA)   // violet

        // Semantic
        static let success = Color(hex: 0x34D399)
        static let warning = Color(hex: 0xFBBF24)
        static let danger  = Color(hex: 0xF87171)
    }

    /// Glass tint used for material card borders (bright edge highlight).
    static func glassBorder(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [Color.white.opacity(0.35), Color.white.opacity(0.06)]
                : [Color.white.opacity(0.95), Color.white.opacity(0.35)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    /// Subtle translucent fill for chips placed on top of glass cards.
    static func chipFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.55)
    }

    // MARK: Adaptive surfaces — graphite
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x0A0C10) : Color(hex: 0xEEF1F5)
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x14181F) : Color.white
    }

    static func surfaceElevated(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x1C212A) : Color.white
    }

    static func separator(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.06)
    }

    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xF3F5F8) : Color(hex: 0x121620)
    }

    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x97A0AE) : Color(hex: 0x69717E)
    }

    // MARK: Gradients
    static var energyGradient: LinearGradient {
        LinearGradient(
            colors: [Palette.brandSoft, Palette.brand, Palette.brandDeep],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    static let calorieGradient = LinearGradient(
        colors: [Palette.calorieSoft, Palette.calorie],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static func heroGradient(_ scheme: ColorScheme) -> LinearGradient {
        scheme == .dark
        ? LinearGradient(colors: [Color(hex: 0x101622), Color(hex: 0x0A0C10)],
                         startPoint: .top, endPoint: .bottom)
        : LinearGradient(colors: [Color(hex: 0xE6EEFB), Color(hex: 0xEEF1F5)],
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
