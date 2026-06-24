import Foundation
import SwiftUI

struct LogLine: Identifiable {
    let id = UUID()
    let date: Date
    let text: String

    var color: Color {
        let u = text.uppercased()
        if u.contains("ERROR") || u.contains("FATAL") { return .red }
        if u.contains("WARN") { return .orange }
        return .primary
    }
}

@MainActor
final class LogStore: ObservableObject {
    @Published private(set) var lines: [LogLine] = []
    private let limit = 1200

    func append(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        lines.append(LogLine(date: Date(), text: t))
        if lines.count > limit { lines.removeFirst(lines.count - limit) }
    }

    func clear() { lines.removeAll() }

    var plainText: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        return lines.map { "[\(f.string(from: $0.date))] \($0.text)" }.joined(separator: "\n")
    }
}
