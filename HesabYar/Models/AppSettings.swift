import SwiftUI
import Observation

// MARK: - App Theme

enum AppTheme: String, CaseIterable {
    case blue, purple, green, orange, teal, pink

    var displayName: String {
        switch self {
        case .blue:   return "Blue"
        case .purple: return "Purple"
        case .green:  return "Green"
        case .orange: return "Orange"
        case .teal:   return "Teal"
        case .pink:   return "Pink"
        }
    }

    var primary: Color {
        switch self {
        case .blue:   return Color(red: 0.20, green: 0.60, blue: 0.95)
        case .purple: return Color(red: 0.55, green: 0.25, blue: 0.90)
        case .green:  return Color(red: 0.10, green: 0.75, blue: 0.45)
        case .orange: return Color(red: 0.95, green: 0.50, blue: 0.10)
        case .teal:   return Color(red: 0.10, green: 0.70, blue: 0.75)
        case .pink:   return Color(red: 0.92, green: 0.30, blue: 0.55)
        }
    }

    var gradient: [Color] {
        switch self {
        case .blue:   return [Color(red: 0.10, green: 0.40, blue: 0.85), Color(red: 0.25, green: 0.65, blue: 0.98)]
        case .purple: return [Color(red: 0.40, green: 0.15, blue: 0.80), Color(red: 0.65, green: 0.35, blue: 0.95)]
        case .green:  return [Color(red: 0.05, green: 0.55, blue: 0.30), Color(red: 0.15, green: 0.80, blue: 0.50)]
        case .orange: return [Color(red: 0.80, green: 0.35, blue: 0.05), Color(red: 0.98, green: 0.60, blue: 0.20)]
        case .teal:   return [Color(red: 0.05, green: 0.50, blue: 0.60), Color(red: 0.15, green: 0.75, blue: 0.80)]
        case .pink:   return [Color(red: 0.75, green: 0.15, blue: 0.45), Color(red: 0.95, green: 0.38, blue: 0.65)]
        }
    }

    var icon: String {
        switch self {
        case .blue:   return "drop.fill"
        case .purple: return "diamond.fill"
        case .green:  return "leaf.fill"
        case .orange: return "sun.max.fill"
        case .teal:   return "wave.3.left"
        case .pink:   return "heart.fill"
        }
    }
}

// MARK: - App Settings (Observable Singleton)

@Observable
final class AppSettings {
    static let shared = AppSettings()
    private init() {}

    var language: String {
        get { UserDefaults.standard.string(forKey: "app_language") ?? "en" }
        set { UserDefaults.standard.set(newValue, forKey: "app_language") }
    }

    var theme: AppTheme {
        get { AppTheme(rawValue: UserDefaults.standard.string(forKey: "app_theme") ?? "blue") ?? .blue }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "app_theme") }
    }

    var isEnglish: Bool { language == "en" }

    func t(_ en: String, _ fa: String) -> String {
        isEnglish ? en : fa
    }
}
