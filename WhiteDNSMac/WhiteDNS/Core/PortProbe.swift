import Foundation
import Network

/// Checks whether a local TCP port is accepting connections — used to detect
/// when the StormDNS SOCKS listener is up and ready to serve.
enum PortProbe {

    static func isOpen(host: String, port: Int, timeout: TimeInterval = 1.0) async -> Bool {
        let nwHost = NWEndpoint.Host(host == "localhost" ? "127.0.0.1" : host)
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return false }

        let conn = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        return await withCheckedContinuation { continuation in
            let done = Resolver()

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if done.fire() { conn.cancel(); continuation.resume(returning: true) }
                case .failed, .cancelled:
                    if done.fire() { continuation.resume(returning: false) }
                default:
                    break
                }
            }
            conn.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if done.fire() { conn.cancel(); continuation.resume(returning: false) }
            }
        }
    }

    /// One-shot guard so the continuation resumes exactly once.
    private final class Resolver {
        private let lock = NSLock()
        private var fired = false
        func fire() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if fired { return false }
            fired = true
            return true
        }
    }
}
