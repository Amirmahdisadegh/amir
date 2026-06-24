import Foundation

/// Toggles the macOS system-wide SOCKS proxy so all apps route through the
/// local StormDNS listener. Setting proxy state requires admin rights, so the
/// change is applied through a single `do shell script ... with administrator
/// privileges` call (one password prompt per toggle).
enum SystemProxy {

    enum ProxyError: LocalizedError {
        case noActiveService
        case authorizationFailed(String)

        var errorDescription: String? {
            switch self {
            case .noActiveService:
                return "Could not determine the active network service (Wi-Fi/Ethernet)."
            case .authorizationFailed(let m):
                return "Failed to update the system proxy: \(m)"
            }
        }
    }

    /// Name of the network service that carries the default route, e.g. "Wi-Fi".
    static func primaryService() -> String? {
        guard
            let iface = run("/sbin/route", ["-n", "get", "default"])?
                .lineMatching(prefix: "interface:")?
                .components(separatedBy: ":").last?
                .trimmingCharacters(in: .whitespaces),
            !iface.isEmpty,
            let order = run("/usr/sbin/networksetup", ["-listnetworkserviceorder"])
        else { return nil }
        return service(forDevice: iface, in: order)
    }

    static func enable(host: String, port: Int, service: String) throws {
        let cmd = """
        networksetup -setsocksfirewallproxy \(q(service)) \(q(host)) \(port) && \
        networksetup -setsocksfirewallproxystate \(q(service)) on
        """
        try runPrivileged(cmd)
    }

    static func disable(service: String) throws {
        try runPrivileged("networksetup -setsocksfirewallproxystate \(q(service)) off")
    }

    /// True when this service currently points its SOCKS proxy at host:port.
    static func isEnabled(host: String, port: Int, service: String) -> Bool {
        guard let out = run("/usr/sbin/networksetup", ["-getsocksfirewallproxy", service]) else { return false }
        return out.contains("Enabled: Yes")
            && out.contains(host)
            && out.contains("\(port)")
    }

    // MARK: - Helpers

    private static func service(forDevice device: String, in order: String) -> String? {
        // Blocks look like:
        //   (1) Wi-Fi
        //   (Hardware Port: Wi-Fi, Device: en0)
        let lines = order.components(separatedBy: .newlines)
        for (i, line) in lines.enumerated() where line.contains("Device: \(device))") {
            if i > 0 {
                // Strip the leading "(N) " ordinal from the name line.
                let name = lines[i - 1]
                if let r = name.range(of: ") ") {
                    return String(name[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }

    private static func q(_ s: String) -> String { "'\(s.replacingOccurrences(of: "'", with: "'\\''"))'" }

    @discardableResult
    private static func run(_ path: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }

    private static func runPrivileged(_ shellCommand: String) throws {
        // Escape for embedding inside an AppleScript string literal.
        let escaped = shellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"

        var errorInfo: NSDictionary?
        let script = NSAppleScript(source: source)
        _ = script?.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let msg = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "unknown error"
            throw ProxyError.authorizationFailed(msg)
        }
    }
}

private extension String {
    func lineMatching(prefix: String) -> String? {
        components(separatedBy: .newlines)
            .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) }
    }
}
