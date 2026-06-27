import Foundation

/// A persistent root helper (LaunchDaemon) that runs the sing-box core in TUN
/// mode. It is installed once (a single admin-password prompt); afterwards the
/// app starts/stops the tunnel by writing control files — no further prompts.
enum HelperManager {

    static let dir = "/Library/Application Support/AmirV2ray"
    static let plistPath = "/Library/LaunchDaemons/com.amirv2ray.helper.plist"
    static let label = "com.amirv2ray.helper"
    static let version = "1"   // bump to force a reinstall if the runner changes

    static var configPath: String { "\(dir)/config.json" }
    static var statePath: String { "\(dir)/state" }
    static var logPath: String { "\(dir)/singbox.log" }
    static var corePath: String { "\(dir)/core" }
    private static var versionPath: String { "\(dir)/version" }

    enum HelperError: LocalizedError {
        case installFailed(String)
        var errorDescription: String? {
            switch self {
            case .installFailed(let m): return "Could not install the VPN helper: \(m)"
            }
        }
    }

    /// True when the helper is installed and matches the current version.
    static var isInstalled: Bool {
        guard FileManager.default.fileExists(atPath: plistPath) else { return false }
        let v = (try? String(contentsOfFile: versionPath))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return v == version
    }

    /// Installs/updates the helper with one admin prompt.
    static func install(bundledCore: URL, workDir: URL) throws {
        let runner = workDir.appendingPathComponent("runner.sh")
        try runnerScript().write(to: runner, atomically: true, encoding: .utf8)
        let plist = workDir.appendingPathComponent("helper.plist")
        try plistXML().write(to: plist, atomically: true, encoding: .utf8)

        let cmd = [
            "mkdir -p \(q(dir))",
            "cp \(q(bundledCore.path)) \(q(corePath))",
            "cp \(q(runner.path)) \(q(dir))/runner.sh",
            "chown root:wheel \(q(corePath)) \(q(dir))/runner.sh",
            "chmod 755 \(q(corePath)) \(q(dir))/runner.sh",
            "chmod 777 \(q(dir))",
            "printf down > \(q(statePath))",
            "printf %s \(q(version)) > \(q(versionPath))",
            "cp \(q(plist.path)) \(q(plistPath))",
            "chown root:wheel \(q(plistPath))",
            "chmod 644 \(q(plistPath))",
            "launchctl bootout system \(q(plistPath)) 2>/dev/null || true",
            "launchctl bootstrap system \(q(plistPath))",
        ].joined(separator: "; ")

        let out = try SystemProxy.adminCapturing(cmd)
        if out.lowercased().contains("bootstrap failed") || out.lowercased().contains("error:") {
            throw HelperError.installFailed(out.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// Writes the config and toggles the tunnel on/off (no password).
    static func setRunning(_ up: Bool, config: String?) {
        if let config { try? config.write(toFile: configPath, atomically: true, encoding: .utf8) }
        try? (up ? "up" : "down").write(toFile: statePath, atomically: true, encoding: .utf8)
    }

    // MARK: - Generated files

    private static func runnerScript() -> String {
        """
        #!/bin/bash
        D="\(dir)"
        while true; do
          want=$(cat "$D/state" 2>/dev/null)
          pid=$(cat "$D/core.pid" 2>/dev/null)
          alive=0; [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && alive=1
          if [ "$want" = "up" ] && [ -f "$D/config.json" ]; then
            if [ "$alive" = "0" ]; then
              "$D/core" run -c "$D/config.json" >"$D/singbox.log" 2>&1 &
              echo $! > "$D/core.pid"
            fi
          else
            [ "$alive" = "1" ] && kill "$pid" 2>/dev/null
            rm -f "$D/core.pid"
          fi
          sleep 1
        done
        """
    }

    private static func plistXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/bash</string>
                <string>\(dir)/runner.sh</string>
            </array>
            <key>RunAtLoad</key><true/>
            <key>KeepAlive</key><true/>
        </dict>
        </plist>
        """
    }

    private static func q(_ s: String) -> String { "'\(s.replacingOccurrences(of: "'", with: "'\\''"))'" }
}
