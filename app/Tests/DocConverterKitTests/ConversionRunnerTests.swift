import Foundation
import Testing
@testable import DocConverterKit

/// Tạo một "python" giả: in các dòng sự kiện, ghi tham số nhận được và stdin ra tệp, rồi thoát với `status`.
func fakePython(lines: [String], status: Int32 = 0, sleepBeforeExit: Double = 0) throws -> (URL, URL) {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let log = dir.appendingPathComponent("args.txt")
    let body = lines.map { "printf '%s\\n' '\($0)'" }.joined(separator: "\n")
    let script = """
    #!/bin/sh
    echo "$@" > '\(log.path)'
    cat >> '\(log.path)'
    \(body)
    echo "log thư viện" >&2
    trap 'exit 130' TERM
    sleep \(sleepBeforeExit) & wait
    exit \(status)
    """
    let url = dir.appendingPathComponent("python")
    try script.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return (url, log)
}

@MainActor
final class Collector {
    var events: [ConversionEvent] = []
    var exit: (Int32, String)?
}

@MainActor
func waitUntil(_ condition: @MainActor () -> Bool, timeout: Double = 10) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        try? await Task.sleep(for: .milliseconds(20))
    }
}

@Test @MainActor func runnerDeliversEventsInOrderAndExitStatus() async throws {
    let lines = protocolSample.split(separator: "\n").map(String.init)
    let (python, log) = try fakePython(lines: lines, status: 2)
    let runner = ConversionRunner(python: python)
    let c = Collector()
    try runner.start(arguments: ["--to", "md"], manifest: Data("[{\"src\":\"/x.pdf\"}]".utf8),
                     onEvent: { c.events.append($0) }, onExit: { c.exit = ($0, $1) })
    await waitUntil { c.exit != nil }
    #expect(c.events.map(\.kind) == [.start, .progress, .progress, .progress, .done, .start, .error, .register, .finished])
    #expect(c.exit?.0 == 2)
    #expect(c.exit?.1.contains("log thư viện") == true)
    let received = try String(contentsOf: log, encoding: .utf8)
    #expect(received.contains("-m docconv convert --json --manifest - --to md"))
    #expect(received.contains("[{\"src\":\"/x.pdf\"}]"))
}

@Test @MainActor func cancelSendsSigterm() async throws {
    let (python, _) = try fakePython(lines: [#"{"event": "start", "file": "/x.pdf", "index": 1, "total": 1}"#],
                                     sleepBeforeExit: 30)
    let runner = ConversionRunner(python: python)
    let c = Collector()
    try runner.start(arguments: [], manifest: Data("[]".utf8),
                     onEvent: { c.events.append($0) }, onExit: { c.exit = ($0, $1) })
    await waitUntil { !c.events.isEmpty }
    runner.cancel()
    await waitUntil { c.exit != nil }
    #expect(c.exit?.0 == 130)
    #expect(!runner.isRunning)
}
