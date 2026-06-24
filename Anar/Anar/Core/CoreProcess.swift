import Foundation

/// Runs the sing-box core.
///
/// - **Proxy mode** runs it as a normal child process (no root).
/// - **TUN mode** runs it as root through a LaunchDaemon installed with a single
///   administrator prompt, so launchd keeps it alive (unlike a backgrounded
///   `osascript` process, which dies as soon as the prompt returns).
final class CoreProcess {

    enum CoreError: LocalizedError {
        case binaryMissing
        case invalidConfig(String)
        case daemonFailed(String)
        var errorDescription: String? {
            switch self {
            case .binaryMissing: return "sing-box core is missing. Run Scripts/build-cores.sh and rebuild."
            case .invalidConfig(let m): return "Invalid configuration:\n\(m)"
            case .daemonFailed(let m): return "Could not start the VPN service: \(m)"
            }
        }
    }

    private static let daemonLabel = "app.anar.singbox"
    private static let daemonPlist = "/Library/LaunchDaemons/app.anar.singbox.plist"
    // launchd requires daemon executables to be root-owned and in a secure
    // location, so the core is copied here before loading.
    private static let secureDir = "/Library/Application Support/Anar"
    private static let secureBin = "/Library/Application Support/Anar/sing-box"

    var onLine: ((String) -> Void)?
    var onExit: ((Int32) -> Void)?

    private var child: Process?
    private var stdoutPipe: Pipe?
    private var lineBuffer = Data()
    private var expectRunning = false

    private var tailTimer: DispatchSourceTimer?
    private var tailOffset: UInt64 = 0
    private var isDaemon = false

    static func locateBinary(name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: nil)
    }

    // MARK: - Config validation (fail fast with the real error)

    /// Runs `sing-box check -c <config>`. Throws CoreError.invalidConfig on failure.
    func check(binary: URL, configURL: URL) throws {
        try prepareBinary(binary)
        let p = Process()
        p.executableURL = binary
        p.arguments = ["check", "-c", configURL.path]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { throw CoreError.daemonFailed(error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        // `check` exits 0 even on FATAL in some builds, so scan the text too.
        if p.terminationStatus != 0 || output.contains("FATAL") || output.contains("ERROR") {
            let firstError = output
                .split(separator: "\n")
                .first { $0.contains("FATAL") || $0.contains("ERROR") }
                .map(String.init) ?? output
            throw CoreError.invalidConfig(firstError.trimmingCharacters(in: .whitespaces))
        }
    }

    // MARK: - Proxy mode (child process)

    func startChild(binary: URL, configURL: URL, workDir: URL) throws {
        try prepareBinary(binary)
        let p = Process()
        p.executableURL = binary
        p.arguments = ["run", "-c", configURL.path]
        p.currentDirectoryURL = workDir
        let out = Pipe()
        p.standardOutput = out
        p.standardError = out
        p.standardInput = FileHandle.nullDevice
        out.fileHandleForReading.readabilityHandler = { [weak self] h in
            let d = h.availableData
            if !d.isEmpty { self?.consume(d) }
        }
        p.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                guard let self, self.expectRunning else { return }
                self.expectRunning = false
                self.onExit?(proc.terminationStatus)
            }
        }
        try p.run()
        child = p
        stdoutPipe = out
        expectRunning = true
        isDaemon = false
    }

    // MARK: - TUN mode (root LaunchDaemon)

    func startDaemon(binary: URL, configURL: URL, workDir: URL) throws {
        try prepareBinary(binary)
        let logFile = workDir.appendingPathComponent("sing-box.log")
        try? FileManager.default.removeItem(at: logFile)
        FileManager.default.createFile(atPath: logFile.path, contents: nil)

        let plist = workDir.appendingPathComponent("daemon.plist")
        try daemonPlistXML(binPath: Self.secureBin, configURL: configURL, logFile: logFile)
            .write(to: plist, atomically: true, encoding: .utf8)

        let install = [
            "mkdir -p \(sh(Self.secureDir))",
            "cp \(sh(binary.path)) \(sh(Self.secureBin))",
            "chown root:wheel \(sh(Self.secureBin))",
            "chmod 755 \(sh(Self.secureBin))",
            "cp \(sh(plist.path)) \(sh(Self.daemonPlist))",
            "chown root:wheel \(sh(Self.daemonPlist))",
            "chmod 644 \(sh(Self.daemonPlist))",
            "launchctl bootout system \(sh(Self.daemonPlist)) 2>/dev/null || true",
            "launchctl bootstrap system \(sh(Self.daemonPlist))",
        ].joined(separator: "; ")

        let output = try SystemProxy.adminCapturing(install)
        if output.lowercased().contains("error") || output.contains("Bootstrap failed") {
            throw CoreError.daemonFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        isDaemon = true
        tailOffset = 0
        startTailing(logFile)
    }

    func stop() {
        if let p = child, p.isRunning {
            expectRunning = false
            p.terminate()
            let pid = p.processIdentifier
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                if kill(pid, 0) == 0 { kill(pid, SIGKILL) }
            }
        }
        child = nil
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe = nil

        tailTimer?.cancel(); tailTimer = nil

        if isDaemon {
            isDaemon = false
            let stopCmd = "launchctl bootout system \(sh(Self.daemonPlist)) 2>/dev/null; rm -f \(sh(Self.daemonPlist)) 2>/dev/null || true"
            try? SystemProxy.adminCapturing(stopCmd)
        }
    }

    // MARK: - LaunchDaemon plist

    private func daemonPlistXML(binPath: String, configURL: URL, logFile: URL) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>\(Self.daemonLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binPath)</string>
                <string>run</string>
                <string>-c</string>
                <string>\(configURL.path)</string>
            </array>
            <key>RunAtLoad</key><true/>
            <key>StandardOutPath</key><string>\(logFile.path)</string>
            <key>StandardErrorPath</key><string>\(logFile.path)</string>
            <key>ProcessType</key><string>Interactive</string>
        </dict>
        </plist>
        """
    }

    // MARK: - Output

    private func consume(_ chunk: Data) {
        lineBuffer.append(chunk)
        let nl = UInt8(ascii: "\n")
        while let idx = lineBuffer.firstIndex(of: nl) {
            let line = lineBuffer.subdata(in: lineBuffer.startIndex..<idx)
            lineBuffer.removeSubrange(lineBuffer.startIndex...idx)
            emit(line)
        }
    }

    private func emit(_ data: Data) {
        guard let s = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async { [weak self] in self?.onLine?(s) }
    }

    private func startTailing(_ file: URL) {
        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + 0.4, repeating: 0.4)
        timer.setEventHandler { [weak self] in
            guard let self, let handle = try? FileHandle(forReadingFrom: file) else { return }
            defer { try? handle.close() }
            try? handle.seek(toOffset: self.tailOffset)
            let data = handle.readDataToEndOfFile()
            if !data.isEmpty {
                self.tailOffset += UInt64(data.count)
                for line in data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true) {
                    self.emit(Data(line))
                }
            }
        }
        timer.resume()
        tailTimer = timer
    }

    private func prepareBinary(_ url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { throw CoreError.binaryMissing }
        // Strip the quarantine flag so Gatekeeper doesn't block exec (best-effort).
        _ = SystemProxy.shell("/usr/bin/xattr", ["-d", "com.apple.quarantine", url.path])
        if !fm.isExecutableFile(atPath: url.path) {
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }

    private func sh(_ s: String) -> String { "'\(s.replacingOccurrences(of: "'", with: "'\\''"))'" }
}
