import Foundation

/// Wraps the bundled StormDNS Go client binary, run exactly like the Android
/// client does:  `stormdns -config <toml> -resolvers <file>`, reading its
/// stdout/stderr for log + stats lines.
final class StormDnsProcess {

    enum LaunchError: LocalizedError {
        case binaryMissing
        case notExecutable(String)

        var errorDescription: String? {
            switch self {
            case .binaryMissing:
                return "The stormdns core binary is missing from the app bundle. Run Scripts/build-core.sh, then rebuild."
            case .notExecutable(let p):
                return "Cannot make the core binary executable at \(p)."
            }
        }
    }

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var lineBuffer = Data()

    /// Called on the main queue for each output line.
    var onLine: ((String) -> Void)?
    /// Called on the main queue when the process exits (with its status code).
    var onExit: ((Int32) -> Void)?

    var isRunning: Bool { process?.isRunning ?? false }

    /// Locates the core binary: a user override in Application Support wins,
    /// otherwise the copy bundled under Resources.
    static func locateBinary(workDir: URL) -> URL? {
        let override = workDir.appendingPathComponent("stormdns")
        if FileManager.default.isExecutableFile(atPath: override.path) { return override }
        if let bundled = Bundle.main.url(forResource: "stormdns", withExtension: nil) { return bundled }
        return nil
    }

    func start(binary: URL, configPath: URL, resolversPath: URL, workDir: URL) throws {
        try ensureExecutable(binary)

        let proc = Process()
        proc.executableURL = binary
        proc.arguments = ["-config", configPath.path, "-resolvers", resolversPath.path]
        proc.currentDirectoryURL = workDir

        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = out
        // The core may prompt on stdin in some modes; STARTUP_MODE="resolvers"
        // suppresses that, but close stdin defensively so it never blocks.
        proc.standardInput = FileHandle.nullDevice

        out.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            self?.consume(chunk)
        }

        proc.terminationHandler = { [weak self] p in
            let status = p.terminationStatus
            DispatchQueue.main.async {
                out.fileHandleForReading.readabilityHandler = nil
                self?.flushBuffer()
                self?.onExit?(status)
            }
        }

        try proc.run()
        self.process = proc
        self.stdoutPipe = out
    }

    func stop() {
        guard let proc = process, proc.isRunning else { return }
        proc.terminate() // SIGTERM
        // Give it a moment to exit cleanly, then force-kill if needed.
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if proc.isRunning { kill(proc.processIdentifier, SIGKILL) }
        }
    }

    // MARK: - Output handling

    private func consume(_ chunk: Data) {
        lineBuffer.append(chunk)
        let newline = UInt8(ascii: "\n")
        while let idx = lineBuffer.firstIndex(of: newline) {
            let lineData = lineBuffer.subdata(in: lineBuffer.startIndex..<idx)
            lineBuffer.removeSubrange(lineBuffer.startIndex...idx)
            emit(lineData)
        }
    }

    private func flushBuffer() {
        guard !lineBuffer.isEmpty else { return }
        let rest = lineBuffer
        lineBuffer.removeAll()
        emit(rest)
    }

    private func emit(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async { [weak self] in self?.onLine?(text) }
    }

    private func ensureExecutable(_ url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { throw LaunchError.binaryMissing }
        if !fm.isExecutableFile(atPath: url.path) {
            do {
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            } catch {
                throw LaunchError.notExecutable(url.path)
            }
        }
    }
}
