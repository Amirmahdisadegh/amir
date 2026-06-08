import Foundation
import NetworkExtension
import SwiftUI

@MainActor
class DNSManager: ObservableObject {
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var selectedProvider: DNSProvider?
    @Published var errorMessage: String?
    @Published var customProviders: [DNSProvider] = []

    private let manager = NEDNSSettingsManager.shared()

    var allProviders: [DNSProvider] { DNSProvider.presets + customProviders }

    init() {
        loadPersistedData()
        Task { await refreshStatus() }
    }

    func refreshStatus() async {
        await withCheckedContinuation { continuation in
            manager.loadFromPreferences { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isConnected = self?.manager.isEnabled ?? false
                    continuation.resume()
                }
            }
        }
    }

    func connect(provider: DNSProvider) async {
        isLoading = true
        errorMessage = nil

        do {
            let settings = buildSettings(for: provider)
            settings.matchDomains = [""]
            manager.dnsSettings = settings
            manager.localizedDescription = "White DNS"

            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                manager.saveToPreferences { error in
                    if let error { cont.resume(throwing: error) } else { cont.resume() }
                }
            }

            selectedProvider = provider
            isConnected = true
            persistData()

        } catch {
            errorMessage = "خطا در اتصال: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func disconnect() async {
        isLoading = true
        errorMessage = nil

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                manager.removeFromPreferences { error in
                    if let error { cont.resume(throwing: error) } else { cont.resume() }
                }
            }
            isConnected = false
        } catch {
            errorMessage = "خطا در قطع اتصال: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func addCustomProvider(_ provider: DNSProvider) {
        var p = provider
        p.isCustom = true
        customProviders.append(p)
        persistData()
    }

    func deleteCustomProviders(at offsets: IndexSet) {
        customProviders.remove(atOffsets: offsets)
        persistData()
    }

    private func buildSettings(for provider: DNSProvider) -> NEDNSSettings {
        if let urlStr = provider.dohURL, let url = URL(string: urlStr) {
            let s = NEDNSOverHTTPSSettings(servers: provider.servers)
            s.serverURL = url
            return s
        }
        if let host = provider.dotHostname {
            let s = NEDNSOverTLSSettings(servers: provider.servers)
            s.serverName = host
            return s
        }
        return NEDNSSettings(servers: provider.servers)
    }

    private func persistData() {
        if let p = selectedProvider, let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: "wdns_selected")
        }
        if let data = try? JSONEncoder().encode(customProviders) {
            UserDefaults.standard.set(data, forKey: "wdns_custom")
        }
    }

    private func loadPersistedData() {
        if let data = UserDefaults.standard.data(forKey: "wdns_selected"),
           let p = try? JSONDecoder().decode(DNSProvider.self, from: data) {
            selectedProvider = p
        }
        if let data = UserDefaults.standard.data(forKey: "wdns_custom"),
           let ps = try? JSONDecoder().decode([DNSProvider].self, from: data) {
            customProviders = ps
        }
    }
}
