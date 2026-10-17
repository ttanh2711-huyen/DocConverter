import Foundation
import Observation

/// Kiểm tra và thiết lập môi trường Python của app (chạy `bootstrap-env.sh` đi kèm app).
@MainActor @Observable
public final class EnvironmentManager {
    public enum State: Equatable, Sendable {
        case checking
        case needsSetup
        case installing(step: Int, total: Int, title: String)
        case ready(URL)
        case failed(String)
    }

    public private(set) var state: State = .checking
    public private(set) var steps: [String] = []
    public private(set) var log: [String] = []

    private let script: URL?
    private let managedPython: URL
    private let overridePython: () -> URL?

    public init(script: URL?, managedPython: URL, overridePython: @escaping () -> URL?) {
        self.script = script
        self.managedPython = managedPython
        self.overridePython = overridePython
    }

    /// Cấu hình mặc định cho app: script trong Resources, venv trong Application Support.
    public static func forApp(bundle: Bundle = .main) -> EnvironmentManager {
        EnvironmentManager(
            script: bundle.url(forResource: "bootstrap-env", withExtension: "sh"),
            managedPython: PythonLocator.managedEnvironment.appendingPathComponent("bin/python"),
            overridePython: { PythonLocator.override(bundle: bundle) })
    }

    public func refresh() async {
        if let python = overridePython() {
            state = .ready(python)
            return
        }
        guard let script else {
            state = .failed("Thiếu tệp thiết lập môi trường trong app (bootstrap-env.sh).")
            return
        }
        state = .checking
        let status = await Self.run(script, ["--check"]) { _ in }
        state = status == 0 ? .ready(managedPython) : .needsSetup
    }

    public func install() async {
        guard let script else {
            state = .failed("Thiếu tệp thiết lập môi trường trong app (bootstrap-env.sh).")
            return
        }
        steps = []
        log = []
        state = .installing(step: 0, total: 4, title: "Đang bắt đầu…")
        let status = await Self.run(script, []) { [weak self] line in
            guard let self else { return }
            self.log.append(line)
            if self.log.count > 400 { self.log.removeFirst(self.log.count - 400) }
            if let (n, total, title) = Self.parseStep(line) {
                self.steps.append(title)
                self.state = .installing(step: n, total: total, title: title)
            }
        }
        if status == 0 {
            await refresh()
            if state == .needsSetup { state = .failed("Đã cài xong nhưng kiểm tra môi trường không đạt.") }
        } else {
            state = .failed("Thiết lập không thành công (mã \(status)). Kiểm tra kết nối mạng rồi thử lại.")
        }
    }

    nonisolated static func parseStep(_ line: String) -> (Int, Int, String)? {
        let parts = line.split(separator: " ", maxSplits: 2)
        guard parts.count == 3, parts[0] == "STEP" else { return nil }
        let frac = parts[1].split(separator: "/")
        guard frac.count == 2, let n = Int(frac[0]), let total = Int(frac[1]) else { return nil }
        return (n, total, String(parts[2]))
    }

    /// Chạy script, chuyển từng dòng stdout/stderr về main actor, trả về mã thoát.
    private static func run(_ script: URL, _ args: [String], onLine: @escaping @MainActor (String) -> Void) async -> Int32 {
        await withCheckedContinuation { continuation in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = [script.path] + args
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            let buffer = LockedLineBuffer()
            pipe.fileHandleForReading.readabilityHandler = { handle in
                for line in buffer.append(handle.availableData) {
                    DispatchQueue.main.async { MainActor.assumeIsolated { onLine(line) } }
                }
            }
            p.terminationHandler = { proc in
                pipe.fileHandleForReading.readabilityHandler = nil
                let rest = pipe.fileHandleForReading.readDataToEndOfFile()
                let lines = buffer.append(rest + Data("\n".utf8))
                let status = proc.terminationStatus
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { lines.forEach(onLine) }
                    continuation.resume(returning: status)
                }
            }
            do {
                try p.run()
            } catch {
                continuation.resume(returning: -1)
            }
        }
    }
}

private final class LockedLineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = LineBuffer()

    func append(_ data: Data) -> [String] {
        lock.withLock { buffer.append(data) }
    }
}
