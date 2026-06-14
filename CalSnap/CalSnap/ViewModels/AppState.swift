import Foundation
import SwiftUI
import Observation

/// App-wide observable state: user profile, theme preference and onboarding flag.
/// Profile is persisted as JSON in UserDefaults; the Claude API key lives in the Keychain.
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

    var healthSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(healthSyncEnabled, forKey: Keys.healthSync) }
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
        healthSyncEnabled = defaults.bool(forKey: Keys.healthSync)
    }

    private func persistProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Keys.profile)
        }
    }

    private enum Keys {
        static let profile = "calsnap.profile"
        static let theme = "calsnap.theme"
        static let onboarded = "calsnap.onboarded"
        static let healthSync = "calsnap.healthSync"
        static let apiKey = "calsnap.claude.apikey"
    }
}
