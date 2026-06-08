import Foundation

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting(phase: String, progress: Double)
    case connected
    case disconnecting

    var isConnected: Bool { self == .connected }
    var isIdle: Bool {
        if case .disconnected = self { return true }
        return false
    }
}

enum ConnectionMode: String, CaseIterable, Identifiable {
    case vpn   = "VPN"
    case proxy = "پراکسی"
    var id: String { rawValue }
}

struct ConnectionStats {
    var rxBytes: Int64 = 0
    var txBytes: Int64 = 0
    var startDate: Date = .now

    var duration: String {
        let s = Int(Date.now.timeIntervalSince(startDate))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }

    func formatted(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB/s", kb) }
        return String(format: "%.1f MB/s", kb / 1024)
    }

    var rxFormatted: String { formatted(rxBytes) }
    var txFormatted: String { formatted(txBytes) }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let level: Level
    let message: String

    enum Level { case info, warn, error, debug }

    var levelTag: String {
        switch level {
        case .info:  return "INFO "
        case .warn:  return "WARN "
        case .error: return "ERROR"
        case .debug: return "DEBUG"
        }
    }

    static func make(_ msg: String, level: Level = .info) -> LogEntry {
        LogEntry(date: .now, level: level, message: msg)
    }
}

struct ScanResult: Identifiable {
    let id = UUID()
    let server: String
    var latency: Double?
    var status: Status = .pending

    enum Status { case pending, testing, ok, timeout, error }
}
