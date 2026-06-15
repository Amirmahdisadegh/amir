import Foundation
import SwiftUI
import UIKit
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
        // Reactive via preferredColorScheme — no tree rebuild needed.
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: Keys.theme) }
    }

    /// Currently-selected tab. Kept here so it survives appearance rebuilds.
    var selectedTab: AppTab = .home

    // MARK: Appearance customization

    /// Selected accent preset id ("custom" uses customAccentHex).
    var accentID: String {
        didSet {
            applyAccent()
            UserDefaults.standard.set(accentID, forKey: Keys.accent)
            appearanceVersion += 1
        }
    }

    /// Custom accent colour (0xRRGGBB) used when accentID == "custom".
    var customAccentHex: UInt {
        didSet {
            applyAccent()
            UserDefaults.standard.set(Int(customAccentHex), forKey: Keys.customAccent)
            appearanceVersion += 1
        }
    }

    private func applyAccent() {
        Theme.accent = accentID == "custom"
            ? AccentPreset.custom(Color(hex: customAccentHex))
            : AccentPreset.by(id: accentID)
    }

    /// Saves (or clears) the custom background photo and refreshes the UI.
    func setBackgroundPhoto(_ image: UIImage?) {
        AppearanceStore.saveBackgroundPhoto(image)
        Theme.backgroundImage = image
        appearanceVersion += 1
    }

    /// Background treatment id.
    var backgroundID: String {
        didSet {
            Theme.backgroundStyle = BackgroundStyle(rawValue: backgroundID) ?? .aurora
            UserDefaults.standard.set(backgroundID, forKey: Keys.background)
            appearanceVersion += 1
        }
    }

    /// Glass translucency 0…1.
    var glass: Double {
        didSet {
            Theme.glassIntensity = glass
            UserDefaults.standard.set(glass, forKey: Keys.glass)
            appearanceVersion += 1
        }
    }

    /// Bumped on any appearance change so the view tree rebuilds.
    private(set) var appearanceVersion = 0

    var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: Keys.onboarded) }
    }

    /// Manually-entered calories burned, keyed by day (yyyy-MM-dd).
    var burnedByDay: [String: Int] {
        didSet { persistBurned() }
    }

    /// Water intake in millilitres, keyed by day.
    var waterByDay: [String: Int] {
        didSet {
            if let data = try? JSONEncoder().encode(waterByDay) {
                UserDefaults.standard.set(data, forKey: Keys.water)
            }
        }
    }

    /// Daily water goal in millilitres.
    var waterGoalML: Int {
        didSet { UserDefaults.standard.set(waterGoalML, forKey: Keys.waterGoal) }
    }

    /// The AI service currently used for recognition.
    var activeProvider: AIProvider {
        didSet { UserDefaults.standard.set(activeProvider.rawValue, forKey: Keys.provider) }
    }

    /// Bumped whenever a key/model changes so SwiftUI views refresh.
    private(set) var aiConfigVersion = 0

    // MARK: Per-provider API keys (Keychain)

    func apiKey(for provider: AIProvider) -> String? {
        KeychainService.shared.read(key: provider.keychainKey)
    }

    func setAPIKey(_ value: String?, for provider: AIProvider) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            KeychainService.shared.save(key: provider.keychainKey, value: trimmed)
        } else {
            KeychainService.shared.delete(key: provider.keychainKey)
        }
        aiConfigVersion += 1
    }

    func hasKey(for provider: AIProvider) -> Bool {
        !(apiKey(for: provider)?.isEmpty ?? true)
    }

    var hasActiveKey: Bool { hasKey(for: activeProvider) }

    // MARK: Per-provider model (UserDefaults)

    func model(for provider: AIProvider) -> String {
        let stored = UserDefaults.standard.string(forKey: provider.modelDefaultsKey)
        return (stored?.isEmpty == false ? stored! : provider.defaultModel)
    }

    func setModel(_ value: String, for provider: AIProvider) {
        UserDefaults.standard.set(value, forKey: provider.modelDefaultsKey)
        aiConfigVersion += 1
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
        if let data = defaults.data(forKey: Keys.water),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            waterByDay = decoded
        } else {
            waterByDay = [:]
        }
        waterGoalML = defaults.object(forKey: Keys.waterGoal) as? Int ?? 2000
        activeProvider = AIProvider(rawValue: defaults.string(forKey: Keys.provider) ?? "")
            ?? .claude

        customAccentHex = UInt(defaults.object(forKey: Keys.customAccent) as? Int ?? 0x2E9CFF)
        accentID = defaults.string(forKey: Keys.accent) ?? "blue"
        backgroundID = defaults.string(forKey: Keys.background) ?? BackgroundStyle.aurora.rawValue
        glass = defaults.object(forKey: Keys.glass) as? Double ?? 0.6

        // Sync the static Theme appearance before the first render.
        Theme.accent = accentID == "custom"
            ? AccentPreset.custom(Color(hex: customAccentHex))
            : AccentPreset.by(id: accentID)
        Theme.backgroundStyle = BackgroundStyle(rawValue: backgroundID) ?? .aurora
        Theme.glassIntensity = glass
        if Theme.backgroundStyle == .photo {
            Theme.backgroundImage = AppearanceStore.loadBackgroundPhoto()
        }
    }

    // MARK: Burned calories per day

    func burned(on day: Date = .now) -> Int {
        burnedByDay[Self.dayKey(day)] ?? 0
    }

    func setBurned(_ value: Int, on day: Date = .now) {
        burnedByDay[Self.dayKey(day)] = max(0, value)
    }

    // MARK: Water

    func water(on day: Date = .now) -> Int {
        waterByDay[Self.dayKey(day)] ?? 0
    }

    func addWater(_ ml: Int, on day: Date = .now) {
        waterByDay[Self.dayKey(day)] = max(0, water(on: day) + ml)
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
        static let water = "calsnap.waterByDay"
        static let waterGoal = "calsnap.waterGoal"
        static let provider = "calsnap.activeProvider"
        static let accent = "calsnap.accent"
        static let customAccent = "calsnap.customAccent"
        static let background = "calsnap.background"
        static let glass = "calsnap.glass"
    }
}
