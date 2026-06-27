import Foundation
import Network

/// Measures TCP connect latency to a server (reachability + RTT) without needing
/// the tunnel up — used for the per-server ping badges and "Test All".
enum LatencyTester {

    static func ping(host: String, port: Int, timeout: TimeInterval = 3.0) async -> Int? {
        guard port > 0, let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return nil }
        let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        let start = Date()
        return await withCheckedContinuation { cont in
            let done = OnceFlag()
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if done.fire() {
                        let ms = Int(Date().timeIntervalSince(start) * 1000)
                        conn.cancel(); cont.resume(returning: ms)
                    }
                case .failed, .cancelled:
                    if done.fire() { conn.cancel(); cont.resume(returning: nil) }
                default: break
                }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if done.fire() { conn.cancel(); cont.resume(returning: nil) }
            }
        }
    }

    private final class OnceFlag {
        private let lock = NSLock()
        private var fired = false
        func fire() -> Bool { lock.lock(); defer { lock.unlock() }; if fired { return false }; fired = true; return true }
    }
}
