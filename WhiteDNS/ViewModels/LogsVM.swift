import Foundation

@MainActor
class LogsVM: ObservableObject {
    @Published var entries: [LogEntry] = []

    func append(_ msg: String, level: LogEntry.Level = .info) {
        entries.append(LogEntry.make(msg, level: level))
        if entries.count > 500 { entries.removeFirst() }
    }

    func clear() { entries.removeAll() }
}
