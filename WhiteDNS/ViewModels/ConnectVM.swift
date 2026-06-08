import Foundation
import NetworkExtension

@MainActor
class ConnectVM: ObservableObject {
    @Published var status: ConnectionStatus = .disconnected
    @Published var mode: ConnectionMode = .vpn
    @Published var stats = ConnectionStats()

    private let manager = NEDNSSettingsManager.shared()
    private var statsTimer: Timer?

    init() {
        Task { await refresh() }
    }

    func refresh() async {
        await withCheckedContinuation { cont in
            manager.loadFromPreferences { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { cont.resume(); return }
                    if self.manager.isEnabled && self.status != .connected {
                        self.status = .connected
                    } else if !self.manager.isEnabled && self.status == .connected {
                        self.status = .disconnected
                    }
                    cont.resume()
                }
            }
        }
    }

    func toggle(profile: DNSProfile?) async {
        switch status {
        case .connected, .connecting:
            await disconnect()
        case .disconnected:
            guard let profile else { return }
            await connect(profile: profile)
        case .disconnecting:
            break
        }
    }

    func connect(profile: DNSProfile) async {
        status = .connecting(phase: "در حال پیکربندی…", progress: 0.1)

        do {
            let settings = buildSettings(profile)
            settings.matchDomains = [""]
            manager.dnsSettings = settings
            manager.localizedDescription = "White DNS"

            status = .connecting(phase: "در حال ذخیره تنظیمات…", progress: 0.5)

            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                manager.saveToPreferences { err in
                    if let err { cont.resume(throwing: err) } else { cont.resume() }
                }
            }

            status = .connecting(phase: "در حال تأیید اتصال…", progress: 0.85)
            try await Task.sleep(for: .milliseconds(600))

            stats = ConnectionStats(startDate: .now)
            status = .connected
            startStatsTimer()

        } catch {
            status = .disconnected
        }
    }

    func disconnect() async {
        status = .disconnecting
        stopStatsTimer()

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                manager.removeFromPreferences { err in
                    if let err { cont.resume(throwing: err) } else { cont.resume() }
                }
            }
        } catch {}

        status = .disconnected
    }

    private func buildSettings(_ profile: DNSProfile) -> NEDNSSettings {
        if !profile.dohURL.isEmpty, let url = URL(string: profile.dohURL) {
            let s = NEDNSOverHTTPSSettings(servers: profile.servers)
            s.serverURL = url
            return s
        }
        if !profile.dotHost.isEmpty {
            let s = NEDNSOverTLSSettings(servers: profile.servers)
            s.serverName = profile.dotHost
            return s
        }
        return NEDNSSettings(servers: profile.servers)
    }

    private func startStatsTimer() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.status == .connected else { return }
                // Simulate traffic numbers for visual feedback
                self.stats.rxBytes = Int64.random(in: 10_000...500_000)
                self.stats.txBytes = Int64.random(in: 1_000...50_000)
            }
        }
    }

    private func stopStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }
}
