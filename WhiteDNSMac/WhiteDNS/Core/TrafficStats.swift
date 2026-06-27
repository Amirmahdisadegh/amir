import Foundation

/// Best-effort traffic snapshot derived from the StormDNS stats log lines.
/// The core prints upload/download speed and cumulative totals every
/// STATS_REPORT_INTERVAL_SECONDS; the exact wording can vary between builds,
/// so this parser is deliberately lenient and degrades to "unknown".
struct TrafficSnapshot: Equatable {
    var uploadSpeed: String = "—"
    var downloadSpeed: String = "—"
    var uploadTotal: String = "—"
    var downloadTotal: String = "—"

    static let empty = TrafficSnapshot()
}

enum TrafficStatsParser {

    /// Returns an updated snapshot if `line` looks like a stats report,
    /// otherwise nil.
    static func parse(_ line: String, into current: TrafficSnapshot) -> TrafficSnapshot? {
        let lower = line.lowercased()
        // A stats line mentions a rate unit and an up/down indicator.
        let mentionsRate = lower.contains("/s") || lower.contains("bps")
        let mentionsDirection = lower.contains("up") || lower.contains("down")
            || line.contains("↑") || line.contains("↓")
        guard mentionsRate || (mentionsDirection && lower.contains("total")) else { return nil }

        var snap = current
        if let up = value(after: ["↑", "up", "upload", "tx", "sent"], in: line, unit: .rate) {
            snap.uploadSpeed = up
        }
        if let down = value(after: ["↓", "down", "download", "rx", "recv", "received"], in: line, unit: .rate) {
            snap.downloadSpeed = down
        }
        if let upT = value(after: ["up total", "uploaded", "tx total", "sent total"], in: line, unit: .size) {
            snap.uploadTotal = upT
        }
        if let downT = value(after: ["down total", "downloaded", "rx total", "received total"], in: line, unit: .size) {
            snap.downloadTotal = downT
        }
        return snap == current ? nil : snap
    }

    private enum Unit { case rate, size }

    /// Finds the first "<number> <unit>" token that follows any of the keywords.
    private static func value(after keywords: [String], in line: String, unit: Unit) -> String? {
        let lower = line.lowercased()
        for kw in keywords {
            guard let r = lower.range(of: kw) else { continue }
            let tail = String(line[r.upperBound...])
            if let m = firstQuantity(in: tail, unit: unit) { return m }
        }
        return nil
    }

    private static func firstQuantity(in text: String, unit: Unit) -> String? {
        let unitPattern = unit == .rate
            ? "(?:[KMGT]?i?B/s|[kmgt]?bps|B/s)"
            : "(?:[KMGT]?i?B|bytes?)"
        let pattern = "([0-9]+(?:\\.[0-9]+)?)\\s*(\(unitPattern))"
        guard
            let re = try? NSRegularExpression(pattern: pattern),
            let match = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let numR = Range(match.range(at: 1), in: text),
            let unitR = Range(match.range(at: 2), in: text)
        else { return nil }
        return "\(text[numR]) \(text[unitR])"
    }
}
