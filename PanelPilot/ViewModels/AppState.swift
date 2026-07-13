import SwiftUI
import Observation

/// Top-level app phase.
enum AppPhase {
    case setup      // no credentials yet — show onboarding
    case locked     // biometric lock engaged
    case ready      // main tab UI
}

/// App-wide state: authentication, biometric lock, and user settings.
@MainActor
@Observable
final class AppState {
    var phase: AppPhase = .setup
    var config: PanelConfig

    // Persisted user settings (mirrored to UserDefaults)
    var biometricLockEnabled: Bool {
        didSet { UserDefaults.standard.set(biometricLockEnabled, forKey: "biometricLock") }
    }
    var allowInsecureTLS: Bool {
        didSet {
            UserDefaults.standard.set(allowInsecureTLS, forKey: "allowInsecureTLS")
            Task { await APIClient.shared.setInsecureTLS(allowInsecureTLS) }
        }
    }
    var mockMode: Bool {
        didSet {
            UserDefaults.standard.set(mockMode, forKey: "mockMode")
            Task { await APIClient.shared.setMockMode(mockMode) }
        }
    }

    let store: DataStore

    init(store: DataStore) {
        self.store = store
        let saved = KeychainStore.loadConfig()
        self.config = saved ?? .default
        self.biometricLockEnabled = UserDefaults.standard.bool(forKey: "biometricLock")
        self.allowInsecureTLS = UserDefaults.standard.bool(forKey: "allowInsecureTLS")
        self.mockMode = UserDefaults.standard.bool(forKey: "mockMode")

        // If we have stored credentials, go straight to (optionally locked) main UI.
        if saved != nil {
            phase = biometricLockEnabled && BiometricAuth.available ? .locked : .ready
        } else {
            phase = .setup
        }
    }

    /// Called once at launch to sync the API actor and warm the cache.
    func bootstrap() async {
        await APIClient.shared.setInsecureTLS(allowInsecureTLS)
        await APIClient.shared.setMockMode(mockMode)
        store.loadFromCache()
        if phase == .ready {
            await store.refreshAll()
        }
    }

    /// Attempt initial login from the setup screen.
    func connect(with newConfig: PanelConfig, twoFactorCode: String = "") async throws {
        config = newConfig
        await APIClient.shared.setInsecureTLS(allowInsecureTLS)
        await APIClient.shared.updateConfig(newConfig)
        await APIClient.shared.setTwoFactorCode(twoFactorCode)
        try await APIClient.shared.login()
        // Success — persist and move on.
        KeychainStore.saveConfig(newConfig)
        phase = biometricLockEnabled && BiometricAuth.available ? .locked : .ready
        await store.refreshAll()
    }

    /// Update the panel connection from Settings, forcing a fresh login.
    func updateConnection(_ newConfig: PanelConfig, twoFactorCode: String = "") async throws {
        config = newConfig
        await APIClient.shared.updateConfig(newConfig)
        await APIClient.shared.setTwoFactorCode(twoFactorCode)
        try await APIClient.shared.login()
        KeychainStore.saveConfig(newConfig)
        await store.refreshAll()
    }

    func unlock() async {
        let ok = await BiometricAuth.authenticate()
        if ok { phase = .ready; await store.refreshAll() }
    }

    func lockIfNeeded() {
        if biometricLockEnabled && BiometricAuth.available && phase == .ready {
            phase = .locked
        }
    }

    func signOut() {
        KeychainStore.deleteConfig()
        config = .default
        store.clear()
        phase = .setup
    }
}
