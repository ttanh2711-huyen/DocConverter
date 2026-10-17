import Foundation
import Testing
@testable import DocConverterKit

/// Script bootstrap giả: `--check` trả về `checkStatus`; cài đặt in các bước rồi thoát với `installStatus`.
func fakeBootstrap(checkStatus: Int32, installStatus: Int32, markReady: Bool = true) throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let flag = dir.appendingPathComponent("installed")
    let script = """
    #!/bin/sh
    if [ "$1" = "--check" ]; then
      [ -f '\(flag.path)' ] && exit 0
      exit \(checkStatus)
    fi
    echo "STEP 1/4 Chuẩn bị Python 3.12"
    echo "log phụ"
    echo "STEP 2/4 Cài thư viện chuyển đổi"
    echo "lỗi mạng giả" >&2
    \(markReady && installStatus == 0 ? "touch '\(flag.path)'" : "")
    exit \(installStatus)
    """
    let url = dir.appendingPathComponent("bootstrap-env.sh")
    try script.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
}

let fakeManagedPython = URL(fileURLWithPath: "/tmp/venv/bin/python")

@Test @MainActor func overridePythonMeansReadyWithoutCheck() async {
    let env = EnvironmentManager(script: nil, managedPython: fakeManagedPython, overridePython: { URL(fileURLWithPath: "/dev/python") })
    await env.refresh()
    #expect(env.state == .ready(URL(fileURLWithPath: "/dev/python")))
}

@Test @MainActor func checkFailureNeedsSetup() async throws {
    let env = EnvironmentManager(script: try fakeBootstrap(checkStatus: 1, installStatus: 0),
                                 managedPython: fakeManagedPython, overridePython: { nil })
    await env.refresh()
    #expect(env.state == .needsSetup)
}

@Test @MainActor func installReportsStepsThenBecomesReady() async throws {
    let env = EnvironmentManager(script: try fakeBootstrap(checkStatus: 1, installStatus: 0),
                                 managedPython: fakeManagedPython, overridePython: { nil })
    await env.install()
    #expect(env.steps == ["Chuẩn bị Python 3.12", "Cài thư viện chuyển đổi"])
    #expect(env.state == .ready(fakeManagedPython))
}

@Test @MainActor func installFailureKeepsLogForRetry() async throws {
    let env = EnvironmentManager(script: try fakeBootstrap(checkStatus: 1, installStatus: 3),
                                 managedPython: fakeManagedPython, overridePython: { nil })
    await env.install()
    guard case .failed(let message) = env.state else { Issue.record("phải báo lỗi"); return }
    #expect(message.contains("mã 3"))
    #expect(env.log.contains("lỗi mạng giả"))
}

@Test func stepParsing() {
    let step = EnvironmentManager.parseStep("STEP 2/4 Cài thư viện")
    #expect(step?.0 == 2 && step?.1 == 4 && step?.2 == "Cài thư viện")
    #expect(EnvironmentManager.parseStep("Downloading torch") == nil)
}
