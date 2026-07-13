import SwiftUI

/// Central design tokens for PanelPilot's premium dark theme.
enum Theme {
    // MARK: - Colors
    /// Deep background #0B0F1A
    static let background = Color(hex: 0x0B0F1A)
    static let backgroundElevated = Color(hex: 0x111726)
    static let cardStroke = Color.white.opacity(0.08)

    static let accentIndigo = Color(hex: 0x6366F1)
    static let accentCyan = Color(hex: 0x22D3EE)

    static let online = Color(hex: 0x34D399)
    static let offline = Color(hex: 0x6B7280)
    static let expired = Color(hex: 0xF87171)
    static let warning = Color(hex: 0xFBBF24)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)

    // MARK: - Gradients
    static let accentGradient = LinearGradient(
        colors: [accentIndigo, accentCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradientHorizontal = LinearGradient(
        colors: [accentIndigo, accentCyan],
        startPoint: .leading,
        endPoint: .trailing
    )

    static func trafficGradient(for fraction: Double) -> LinearGradient {
        if fraction >= 0.8 {
            return LinearGradient(colors: [warning, expired], startPoint: .leading, endPoint: .trailing)
        }
        return accentGradientHorizontal
    }

    // MARK: - Layout
    static let cornerRadius: CGFloat = 20
    static let cardPadding: CGFloat = 16

    static let springResponse: Double = 0.42
    static let springDamping: Double = 0.82

    static var spring: Animation { .spring(response: springResponse, dampingFraction: springDamping) }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
