import Foundation
import SwiftUI
import Observation

/// App-wide observable state: user profile, theme preference, onboarding flag and
/// a manually-entered "calories burned" value per day. Profile and burned values
/// are persisted in UserDefaults; the Claude API key lives in the Keychain.
@Observable
final class AppState {

    var profile: UserProfile {
        didSet { persistProfile() }
    }

    var themeMode: AppThemeMode {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: Keys.theme) }
    }

    var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: Keys.onboarded) }
    }

    /// Manually-entered calories burned, keyed by day (yyyy-MM-dd).
    var burnedByDay: [String: Int] {
        didSet { persistBurned() }
    }

    /// Whether a Claude API key is configured.
    var hasAPIKey: Bool { !(apiKey?.isEmpty ?? true) }

    var apiKey: String? {
        get { KeychainService.shared.read(key: Keys.apiKey) }
        set {
            if let newValue, !newValue.isEmpty {
                KeychainService.shared.save(key: Keys.apiKey, value: newValue)
            } else {
                KeychainService.shared.delete(key: Keys.apiKey)
            }
        }
    }

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Keys.profile),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = decoded
        } else {
            profile = UserProfile()
        }
        themeMode = AppThemeMode(rawValue: defaults.string(forKey: Keys.theme) ?? "")
            ?? .system
        hasOnboarded = defaults.bool(forKey: Keys.onboarded)
        if let data = defaults.data(forKey: Keys.burned),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            burnedByDay = decoded
        } else {
            burnedByDay = [:]
        }
    }

    // MARK: Burned calories per day

    func burned(on day: Date = .now) -> Int {
        burnedByDay[Self.dayKey(day)] ?? 0
    }

    func setBurned(_ value: Int, on day: Date = .now) {
        burnedByDay[Self.dayKey(day)] = max(0, value)
    }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: Persistence

    private func persistProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Keys.profile)
        }
    }

    private func persistBurned() {
        if let data = try? JSONEncoder().encode(burnedByDay) {
            UserDefaults.standard.set(data, forKey: Keys.burned)
        }
    }

    private enum Keys {
        static let profile = "calsnap.profile"
        static let theme = "calsnap.theme"
        static let onboarded = "calsnap.onboarded"
        static let burned = "calsnap.burnedByDay"
        static let apiKey = "calsnap.claude.apikey"
    }
}
