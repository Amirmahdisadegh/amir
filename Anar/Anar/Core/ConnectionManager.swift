import Foundation
import SwiftUI

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var isConnected: Bool { self == .connected }
    var isBusy: Bool { self == .connecting }
}

/// One per-second traffic data point for the live chart.
struct TrafficSample: Identifiable {
    let id = UUID()
    let date: Date
    let up: Int
    let down: Int
}

@MainActor
final class ConnectionManager: ObservableObject {

    @Published private(set) var state: ConnectionState = .disconnected
    @Published private(set) var upSpeed: Int = 0      // bytes/s
    @Published private(set) var downSpeed: Int = 0
    @Published private(set) var upTotal: Int = 0
    @Published private(set) var downTotal: Int = 0
    @Published private(set) var latencyMs: Int? = nil
    @Published private(set) var activeName: String = ""
    @Published private(set) var trafficSamples: [TrafficSample] = []
    @Published private(set) var connectedSince: Date? = nil
    @Published private(set) var exitInfo: GeoInfo? = nil
    @Published var warning: String?

    let log: LogStore

    private let core = CoreProcess()
    private let workDir: URL
    private var settings = AppSettings()
    private var statsTask: Task<Void, Never>?
    private var readyTask: Task<Void, Never>?
    private var proxyService: String?
    private var lastTotals: ClashAPI.Totals?

    private var api: ClashAPI { ClashAPI(port: settings.clashApiPort) }

    init(log: LogStore) {
        self.log = log
        self.workDir = ConnectionManager.makeWorkDir()
        core.onLine = { line in
            MainActor.assumeIsolated { [weak self] in self?.log.append(line) }
        }
        core.onExit = { status in
            MainActor.assumeIsolated { [weak self] in self?.handleCoreExit(status) }
        }
    }

    /// The core process died while we expected it running — surface the failure.
    private func handleCoreExit(_ status: Int32) {
        guard state == .connecting || state == .connected else { return }
        readyTask?.cancel(); readyTask = nil
        statsTask?.cancel(); statsTask = nil
        removeSystemProxy()
        let recent = log.lines.suffix(3).map(\.text).joined(separator: " · ")
        state = .error(recent.isEmpty ? "Core stopped unexpectedly (code \(status))" : recent)
        log.append("!!! sing-box exited (code \(status))")
        upSpeed = 0; downSpeed = 0
        connectedSince = nil
        exitInfo = nil
    }

    // MARK: - Public

    func toggle(_ profile: ProxyProfile?, settings: AppSettings) {
        if state.isConnected || state.isBusy { disconnect() }
        else if let profile { connect(profile, settings: settings) }
    }

    func connect(_ profile: ProxyProfile, settings: AppSettings) {
        guard state == .disconnected || isError else { return }
        guard profile.isValid else { state = .error("Profile is incomplete"); return }
        guard let binary = CoreProcess.locateBinary(name: "sing-box") else {
            state = .error("sing-box core missing — run Scripts/build-cores.sh"); return
        }

        self.settings = settings
        self.activeName = profile.name
        self.warning = nil
        self.latencyMs = nil

        do {
            let configURL = workDir.appendingPathComponent("config.json")
            let data = try SingboxConfig.generate(profile: profile, settings: settings)
            try data.write(to: configURL)

            // Validate the config first so a bad server shows a precise error
            // instead of a silent failure.
            try core.check(binary: binary, configURL: configURL)

            log.append(">>> Connecting to \(profile.name) [\(profile.type.display), \(settings.mode.display)]")
            state = .connecting

            switch settings.mode {
            case .proxy:
                try core.startChild(binary: binary, configURL: configURL, workDir: workDir)
            case .tun:
                try core.startDaemon(binary: binary, configURL: configURL, workDir: workDir)
            }
            startReadyWatch()
        } catch {
            state = .error(error.localizedDescription)
            log.append("!!! \(error.localizedDescription)")
        }
    }

    func disconnect() {
        readyTask?.cancel(); readyTask = nil
        statsTask?.cancel(); statsTask = nil
        removeSystemProxy()
        core.stop()
        log.append(">>> Disconnected")
        state = .disconnected
        upSpeed = 0; downSpeed = 0; latencyMs = nil; activeName = ""
        lastTotals = nil
        trafficSamples = []
        connectedSince = nil
        exitInfo = nil
        NotificationService.notify(title: "Anar disconnected", body: "Tunnel is off.")
    }

    func testLatency() {
        Task { [weak self] in
            guard let self else { return }
            let ms = await self.api.delay()
            self.latencyMs = ms
            self.log.append(ms == nil ? ">>> Latency test failed" : ">>> Latency: \(ms!) ms")
        }
    }

    // MARK: - Readiness + stats

    private func startReadyWatch() {
        readyTask = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<120 {
                if Task.isCancelled { return }
                if await self.api.isUp() { self.markConnected(); return }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            self.markTimedOut()
        }
    }

    private func markConnected() {
        guard state == .connecting else { return }
        if settings.mode == .proxy { applySystemProxy() }
        state = .connected
        connectedSince = Date()
        log.append(">>> Connected")
        startStats()
        testLatency()
        fetchExitInfo()
        NotificationService.notify(title: "Anar connected", body: activeName.isEmpty ? "Tunnel is up." : "Connected to \(activeName).")
    }

    private func fetchExitInfo() {
        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 1_200_000_000) // let the tunnel settle
            guard self.state.isConnected else { return }
            if let info = await GeoService.lookup() {
                guard self.state.isConnected else { return }
                self.exitInfo = info
                self.log.append(">>> Exit: \(info.country) (\(info.ip))")
                if !info.country.isEmpty {
                    NotificationService.notify(title: "\(flagEmoji(info.code)) \(info.country)",
                                               body: "Your traffic now exits via \(info.country).")
                }
            }
        }
    }

    private func markTimedOut() {
        guard state == .connecting else { return }
        let recent = log.lines.suffix(2).map(\.text).joined(separator: " · ")
        state = .error(recent.isEmpty ? "Core did not come up — open Logs" : recent)
        log.append("!!! Timed out waiting for sing-box to come up")
        core.stop()
    }

    private func startStats() {
        statsTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if let t = await self.api.totals() {
                    if let prev = self.lastTotals {
                        self.upSpeed = max(0, t.up - prev.up)
                        self.downSpeed = max(0, t.down - prev.down)
                    }
                    self.upTotal = t.up
                    self.downTotal = t.down
                    self.lastTotals = t
                    self.trafficSamples.append(TrafficSample(date: Date(), up: self.upSpeed, down: self.downSpeed))
                    if self.trafficSamples.count > 60 { self.trafficSamples.removeFirst(self.trafficSamples.count - 60) }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    // MARK: - System proxy (proxy mode)

    private func applySystemProxy() {
        guard let service = SystemProxy.primaryService() else {
            warning = "No active network service. Set SOCKS 127.0.0.1:\(settings.mixedPort) manually."
            return
        }
        do {
            try SystemProxy.enable(host: "127.0.0.1", port: settings.mixedPort, service: service)
            proxyService = service
            log.append(">>> System proxy enabled on \(service)")
        } catch {
            warning = error.localizedDescription
            log.append("!!! \(error.localizedDescription)")
        }
    }

    private func removeSystemProxy() {
        guard let service = proxyService else { return }
        try? SystemProxy.disable(service: service)
        proxyService = nil
    }

    private var isError: Bool { if case .error = state { return true } else { return false } }

    private static func makeWorkDir() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Anar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

/// Formats a byte count as a human rate/size string.
func formatBytes(_ bytes: Int, perSecond: Bool = false) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = Double(bytes)
    var i = 0
    while value >= 1024 && i < units.count - 1 { value /= 1024; i += 1 }
    let s = String(format: i == 0 ? "%.0f %@" : "%.1f %@", value, units[i])
    return perSecond ? s + "/s" : s
}
