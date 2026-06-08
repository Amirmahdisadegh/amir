import Foundation
import Network

@MainActor
class ScanVM: ObservableObject {
    @Published var servers: String = "1.1.1.1\n8.8.8.8\n9.9.9.9\n94.140.14.14\n178.22.122.100\n185.51.200.2\n10.202.10.202\n10.202.10.10\n78.157.42.101"
    @Published var results: [ScanResult] = []
    @Published var isScanning = false
    @Published var workers: Double = 4
    @Published var progress: Double = 0

    private var scanTask: Task<Void, Never>?

    func startScan() {
        let list = servers
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        results = list.map { ScanResult(server: $0) }
        isScanning = true
        progress = 0

        scanTask = Task {
            await withTaskGroup(of: Void.self) { group in
                let batchSize = max(1, Int(workers))
                var idx = 0
                while idx < results.count {
                    let end = min(idx + batchSize, results.count)
                    for i in idx..<end {
                        let server = results[i].server
                        let i = i
                        group.addTask { [weak self] in
                            guard let self else { return }
                            await self.updateResult(i, status: .testing)
                            let ms = await self.ping(server)
                            await self.updateResult(i, latency: ms, status: ms != nil ? .ok : .timeout)
                        }
                    }
                    await group.waitForAll()
                    idx = end
                    progress = Double(end) / Double(results.count)
                }
            }
            isScanning = false
            results.sort { ($0.latency ?? .infinity) < ($1.latency ?? .infinity) }
        }
    }

    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    private func updateResult(_ i: Int, latency: Double? = nil, status: ScanResult.Status) {
        guard i < results.count else { return }
        results[i].status = status
        if let l = latency { results[i].latency = l }
    }

    private func ping(_ server: String) async -> Double? {
        let query = Data([
            0xAB, 0xCD, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01
        ])
        let host = NWEndpoint.Host(server)
        guard let port = NWEndpoint.Port(rawValue: 53) else { return nil }
        let conn = NWConnection(host: host, port: port, using: .udp)

        var resumed = false
        let start = Date()

        return await withCheckedContinuation { cont in
            func finish(_ ms: Double?) {
                guard !resumed else { return }
                resumed = true
                conn.cancel()
                cont.resume(returning: ms)
            }

            conn.stateUpdateHandler = { state in
                if state == .ready {
                    conn.send(content: query, completion: .contentProcessed { _ in
                        conn.receive(minimumIncompleteLength: 1, maximumLength: 512) { _, _, _, err in
                            finish(err == nil ? Date().timeIntervalSince(start) * 1000 : nil)
                        }
                    })
                } else if case .failed = state { finish(nil) }
            }

            conn.start(queue: .global(qos: .utility))

            DispatchQueue.global().asyncAfter(deadline: .now() + 3) { finish(nil) }
        }
    }
}
