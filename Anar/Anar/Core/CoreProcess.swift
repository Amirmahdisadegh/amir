import Foundation

/// Runs the sing-box core. In proxy mode it runs as a normal child process; in
/// TUN mode it must run as root (to create the utun device), launched once via
/// an administrator prompt and stopped the same way.
final class CoreProcess {

    enum CoreError: LocalizedError {
        case binaryMissing
        var errorDescription: String? {
            switch self {
            case .binaryMissing: return "sing-box core is missing from the app bundle. Run Scripts/build-cores.sh and rebuild."
            }
        }
    }

    var onLine: ((String) -> Void)?

    private var child: Process?            // proxy mode
    private var stdoutPipe: Pipe?
    private var lineBuffer = Data()

    private var tailTimer: DispatchSourceTimer?  // tun mode log tail
    private var tailOffset: UInt64 = 0
    private var rootPidFile: URL?

    static func locateBinary(name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: nil)
    }

    // MARK: Proxy mode (child process)

    func startChild(binary: URL, configURL: URL, workDir: URL) throws {
        try makeExecutable(binary)
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
        try p.run()
        child = p
        stdoutPipe = out
    }

    // MARK: TUN mode (root via osascript)

    func startRoot(binary: URL, configURL: URL, workDir: URL) throws {
        try makeExecutable(binary)
        let logFile = workDir.appendingPathComponent("sing-box.log")
        let pidFile = workDir.appendingPathComponent("sing-box.pid")
        try? FileManager.default.removeItem(at: logFile)
        FileManager.default.createFile(atPath: logFile.path, contents: nil)
        rootPidFile = pidFile

        let cmd = "nohup \(sh(binary.path)) run -c \(sh(configURL.path)) >\(sh(logFile.path)) 2>&1 & echo $! >\(sh(pidFile.path))"
        try SystemProxy.admin(cmd)

        tailOffset = 0
        startTailing(logFile)
    }

    func stop() {
        // Proxy mode
        if let p = child, p.isRunning {
            p.terminate()
            let pid = p.processIdentifier
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                if kill(pid, 0) == 0 { kill(pid, SIGKILL) }
            }
        }
        child = nil
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe = nil

        // TUN mode
        tailTimer?.cancel(); tailTimer = nil
        if let pidFile = rootPidFile,
           let pid = (try? String(contentsOf: pidFile))?.trimmingCharacters(in: .whitespacesAndNewlines),
           !pid.isEmpty, Int(pid) != nil {
            try? SystemProxy.admin("kill \(pid) 2>/dev/null || true")
        }
        rootPidFile = nil
    }

    // MARK: Output

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
        timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            guard let handle = try? FileHandle(forReadingFrom: file) else { return }
            defer { try? handle.close() }
            try? handle.seek(toOffset: self.tailOffset)
            let data = handle.readDataToEndOfFile()
            if !data.isEmpty {
                self.tailOffset += UInt64(data.count)
                for line in data.split(separator: UInt8(ascii: "\n")) {
                    self.emit(Data(line))
                }
            }
        }
        timer.resume()
        tailTimer = timer
    }

    private func makeExecutable(_ url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { throw CoreError.binaryMissing }
        if !fm.isExecutableFile(atPath: url.path) {
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }

    private func sh(_ s: String) -> String { "'\(s.replacingOccurrences(of: "'", with: "'\\''"))'" }
}
