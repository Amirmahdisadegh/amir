import SwiftUI

/// Accent color themes selectable in Settings.
enum AppTheme: String, CaseIterable, Identifiable {
    case blue, indigo, purple, pink, red, orange, green, teal

    var id: String { rawValue }
    var display: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .green: return .green
        case .teal: return .teal
        }
    }

    static func color(for name: String) -> Color {
        (AppTheme(rawValue: name) ?? .blue).color
    }
}
