import Foundation
import SwiftUI

struct LogLine: Identifiable {
    let id = UUID()
    let date: Date
    let text: String

    enum Level { case debug, info, warn, error }

    var level: Level {
        let upper = text.uppercased()
        if upper.contains("ERROR") || upper.contains("FATAL") { return .error }
        if upper.contains("WARN") { return .warn }
        if upper.contains("DEBUG") { return .debug }
        return .info
    }

    var color: Color {
        switch level {
        case .debug: return .secondary
        case .info: return .primary
        case .warn: return .orange
        case .error: return .red
        }
    }
}

/// Bounded, observable buffer of subprocess log lines.
@MainActor
final class LogStore: ObservableObject {
    @Published private(set) var lines: [LogLine] = []
    private let limit = 1000

    func append(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lines.append(LogLine(date: Date(), text: trimmed))
        if lines.count > limit {
            lines.removeFirst(lines.count - limit)
        }
    }

    func clear() { lines.removeAll() }

    var plainText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return lines.map { "[\(fmt.string(from: $0.date))] \($0.text)" }.joined(separator: "\n")
    }
}
