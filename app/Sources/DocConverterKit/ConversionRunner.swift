import Foundation

/// Chạy `python -m docconv convert --json …` như tiến trình con và chuyển từng sự kiện về main thread.
public final class ConversionRunner: @unchecked Sendable {
    public typealias EventHandler = @MainActor (ConversionEvent) -> Void
    public typealias ExitHandler = @MainActor (_ status: Int32, _ stderrTail: String) -> Void

    private let python: URL
    private let lock = NSLock()
    private var process: Process?
    private var stdoutBuffer = LineBuffer()
    private var stderrData = Data()

    public init(python: URL) {
        self.python = python
    }

    public var isRunning: Bool {
        lock.withLock { process?.isRunning ?? false }
    }

    /// `manifest` được gửi qua stdin (`--manifest -`).
    public func start(arguments: [String], manifest: Data, onEvent: @escaping EventHandler,
                      onExit: @escaping ExitHandler) throws {
        let p = Process()
        p.executableURL = python
        p.arguments = ["-m", "docconv", "convert", "--json", "--manifest", "-"] + arguments
        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        env["PYTHONIOENCODING"] = "utf-8"
        p.environment = env

        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        p.standardInput = stdin
        p.standardOutput = stdout
        p.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let chunk = handle.availableData
            let lines = self.lock.withLock { self.stdoutBuffer.append(chunk) }
            for line in lines {
                guard let event = try? ConversionEvent.decode(line: line) else { continue }
                DispatchQueue.main.async { MainActor.assumeIsolated { onEvent(event) } }
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let chunk = handle.availableData
            self.lock.withLock {
                self.stderrData.append(chunk)
                if self.stderrData.count > 64_000 { self.stderrData = self.stderrData.suffix(32_000) }
            }
        }
        p.terminationHandler = { [weak self] proc in
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            guard let self else { return }
            // Đọc nốt phần còn lại trong pipe trước khi báo kết thúc.
            let rest = stdout.fileHandleForReading.readDataToEndOfFile()
            let lines = self.lock.withLock { self.stdoutBuffer.append(rest + Data("\n".utf8)) }
            let tail = self.lock.withLock { String(decoding: self.stderrData.suffix(4_000), as: UTF8.self) }
            let status = proc.terminationStatus
            for line in lines {
                guard let event = try? ConversionEvent.decode(line: line) else { continue }
                DispatchQueue.main.async { MainActor.assumeIsolated { onEvent(event) } }
            }
            DispatchQueue.main.async { MainActor.assumeIsolated { onExit(status, tail) } }
        }

        try p.run()
        lock.withLock { process = p }
        stdin.fileHandleForWriting.write(manifest)
        try? stdin.fileHandleForWriting.close()
    }

    /// Gửi SIGTERM; lõi tự dọn tệp dở dang và kết thúc với mã 130.
    public func cancel() {
        lock.withLock { process }?.terminate()
    }
}
