import Foundation

/// Toggles the macOS system SOCKS + HTTP/HTTPS proxy (proxy mode only).
enum SystemProxy {

    enum ProxyError: LocalizedError {
        case noService
        case auth(String)
        var errorDescription: String? {
            switch self {
            case .noService: return "Could not find the active network service."
            case .auth(let m): return "Failed to update system proxy: \(m)"
            }
        }
    }

    static func primaryService() -> String? {
        guard let iface = shell("/sbin/route", ["-n", "get", "default"])?
                .split(separator: "\n")
                .first(where: { $0.contains("interface:") })?
                .split(separator: ":").last?
                .trimmingCharacters(in: .whitespaces),
              let order = shell("/usr/sbin/networksetup", ["-listnetworkserviceorder"])
        else { return nil }
        let lines = order.components(separatedBy: .newlines)
        for (i, line) in lines.enumerated() where line.contains("Device: \(iface))") && i > 0 {
            if let r = lines[i - 1].range(of: ") ") {
                return String(lines[i - 1][r.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    static func enable(host: String, port: Int, service: String) throws {
        let cmd = [
            "networksetup -setsocksfirewallproxy \(q(service)) \(q(host)) \(port)",
            "networksetup -setsocksfirewallproxystate \(q(service)) on",
            "networksetup -setwebproxy \(q(service)) \(q(host)) \(port)",
            "networksetup -setwebproxystate \(q(service)) on",
            "networksetup -setsecurewebproxy \(q(service)) \(q(host)) \(port)",
            "networksetup -setsecurewebproxystate \(q(service)) on",
        ].joined(separator: " && ")
        try admin(cmd)
    }

    static func disable(service: String) throws {
        let cmd = [
            "networksetup -setsocksfirewallproxystate \(q(service)) off",
            "networksetup -setwebproxystate \(q(service)) off",
            "networksetup -setsecurewebproxystate \(q(service)) off",
        ].joined(separator: " && ")
        try admin(cmd)
    }

    // MARK: helpers

    private static func q(_ s: String) -> String { "'\(s.replacingOccurrences(of: "'", with: "'\\''"))'" }

    @discardableResult
    static func shell(_ path: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let d = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: d, encoding: .utf8)
    }

    static func admin(_ shellCommand: String) throws {
        _ = try adminCapturing(shellCommand)
    }

    /// Runs a shell command as root via one admin prompt and returns its output.
    @discardableResult
    static func adminCapturing(_ shellCommand: String) throws -> String {
        let escaped = shellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let src = "do shell script \"\(escaped)\" with administrator privileges"
        var err: NSDictionary?
        let result = NSAppleScript(source: src)?.executeAndReturnError(&err)
        if let err { throw ProxyError.auth((err[NSAppleScript.errorMessage] as? String) ?? "unknown") }
        return result?.stringValue ?? ""
    }
}
