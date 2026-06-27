import Foundation
import SwiftUI

enum ConnectionState: Equatable {
    case disconnected
    case starting          // process launched, scanning resolvers / MTU
    case connected         // SOCKS listener is up
    case error(String)

    var label: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .starting: return "Connecting…"
        case .connected: return "Connected"
        case .error(let m): return "Error: \(m)"
        }
    }

    var isBusy: Bool { self == .starting }
    var isConnected: Bool { self == .connected }
}

/// Orchestrates a connection: render config → launch core → wait for the SOCKS
/// port → flip the system proxy. Mirrors the Android connect/disconnect flow,
/// with "VPN mode" replaced by the macOS system SOCKS proxy.
@MainActor
final class TunnelController: ObservableObject {

    @Published private(set) var state: ConnectionState = .disconnected
    @Published private(set) var traffic: TrafficSnapshot = .empty
    @Published private(set) var activeServerLabel: String = ""
    /// Non-fatal warning surfaced to the UI (e.g. proxy not applied).
    @Published var warning: String?

    let log: LogStore

    private var core = StormDnsProcess()
    private var readinessTask: Task<Void, Never>?
    private var proxyService: String?
    private var proxyApplied = false
    private var settingsSnapshot = AppSettings()

    private let workDir: URL

    init(log: LogStore) {
        self.log = log
        self.workDir = TunnelController.makeWorkDir()
    }

    // MARK: - Public API

    func connect(server: ServerProfile, resolver: ResolverProfile, settings: AppSettings) {
        guard state == .disconnected || isError else { return }
        warning = nil

        guard server.isValid else {
            state = .error("Profile has no domain or key"); return
        }
        guard resolver.isValid else {
            state = .error("No resolvers configured"); return
        }
        guard let binary = StormDnsProcess.locateBinary(workDir: workDir) else {
            state = .error("Core binary missing — run Scripts/build-core.sh"); return
        }

        settingsSnapshot = settings
        activeServerLabel = server.label

        do {
            let configURL = workDir.appendingPathComponent("client_config.toml")
            let resolversURL = workDir.appendingPathComponent("client_resolvers.txt")
            try ConfigRenderer.renderClientToml(server: server, settings: settings)
                .write(to: configURL, atomically: true, encoding: .utf8)
            try ConfigRenderer.renderResolvers(resolver)
                .write(to: resolversURL, atomically: true, encoding: .utf8)

            wireCallbacks()
            log.append(">>> Launching StormDNS core for \(server.label) (\(server.domain))")
            try core.start(binary: binary, configPath: configURL, resolversPath: resolversURL, workDir: workDir)

            state = .starting
            startReadinessWatch()
        } catch {
            state = .error(error.localizedDescription)
            log.append("!!! \(error.localizedDescription)")
        }
    }

    func disconnect() {
        readinessTask?.cancel()
        readinessTask = nil
        removeSystemProxy()
        core.stop()
        log.append(">>> Disconnecting")
        state = .disconnected
        traffic = .empty
        activeServerLabel = ""
    }

    func toggle(server: ServerProfile, resolver: ResolverProfile, settings: AppSettings) {
        if state.isConnected || state.isBusy {
            disconnect()
        } else {
            connect(server: server, resolver: resolver, settings: settings)
        }
    }

    // MARK: - Wiring

    private func wireCallbacks() {
        core.onLine = { line in
            MainActor.assumeIsolated { [weak self] in self?.handleLine(line) }
        }
        core.onExit = { status in
            MainActor.assumeIsolated { [weak self] in self?.handleExit(status) }
        }
    }

    private func handleLine(_ line: String) {
        log.append(line)
        if let snap = TrafficStatsParser.parse(line, into: traffic) {
            traffic = snap
        }
    }

    private func handleExit(_ status: Int32) {
        readinessTask?.cancel()
        readinessTask = nil
        removeSystemProxy()
        traffic = .empty
        if status == 0 || status == 15 /* SIGTERM */ {
            if state != .disconnected { state = .disconnected }
        } else {
            state = .error("Core exited (code \(status))")
            log.append("!!! Core process exited with code \(status)")
        }
    }

    // MARK: - Readiness + proxy

    private func startReadinessWatch() {
        let host = settingsSnapshot.listenIp
        let port = settingsSnapshot.listenPort
        // Task created in a @MainActor context inherits MainActor isolation,
        // so the markConnected/markTimedOut calls run on the main actor.
        readinessTask = Task { [weak self] in
            for _ in 0..<240 { // ~2 minutes at 0.5s cadence
                if Task.isCancelled { return }
                if await PortProbe.isOpen(host: host, port: port) {
                    self?.markConnected()
                    return
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            self?.markTimedOut()
        }
    }

    private func markConnected() {
        guard state == .starting else { return }
        state = .connected
        log.append(">>> SOCKS proxy ready on \(settingsSnapshot.listenIp):\(settingsSnapshot.listenPort)")
        if settingsSnapshot.manageSystemProxy {
            applySystemProxy()
        } else {
            warning = "System proxy not managed — point your apps at SOCKS \(settingsSnapshot.listenIp):\(settingsSnapshot.listenPort)."
        }
    }

    private func markTimedOut() {
        guard state == .starting else { return }
        state = .error("Timed out waiting for the SOCKS listener")
        core.stop()
    }

    private func applySystemProxy() {
        guard let service = SystemProxy.primaryService() else {
            warning = "No active network service found. Set SOCKS \(settingsSnapshot.listenIp):\(settingsSnapshot.listenPort) manually."
            return
        }
        do {
            try SystemProxy.enable(host: settingsSnapshot.listenIp, port: settingsSnapshot.listenPort, service: service)
            proxyService = service
            proxyApplied = true
            log.append(">>> System SOCKS proxy enabled on \(service)")
        } catch {
            warning = error.localizedDescription + " You can set SOCKS \(settingsSnapshot.listenIp):\(settingsSnapshot.listenPort) manually."
            log.append("!!! \(error.localizedDescription)")
        }
    }

    private func removeSystemProxy() {
        guard proxyApplied, let service = proxyService else { return }
        do {
            try SystemProxy.disable(service: service)
            log.append(">>> System SOCKS proxy disabled on \(service)")
        } catch {
            log.append("!!! Could not disable system proxy: \(error.localizedDescription)")
        }
        proxyApplied = false
        proxyService = nil
    }

    private var isError: Bool { if case .error = state { return true } else { return false } }

    private static func makeWorkDir() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("WhiteDNS", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
}
