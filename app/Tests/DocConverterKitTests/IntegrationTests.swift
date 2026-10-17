import Foundation
import Testing
@testable import DocConverterKit

/// Chạy lõi Python thật. Bật bằng: DOCCONV_PYTHON=../core/.venv/bin/python swift test
let realPython = ProcessInfo.processInfo.environment["DOCCONV_PYTHON"]
let coreFixtures = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("core/tests/fixtures")

@Test(.enabled(if: realPython != nil)) @MainActor
func realCoreConvertsCsvAndWordToMarkdown() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Tích hợp \(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for name in ["danh_sach.csv", "quyet_dinh.docx"] {
        try FileManager.default.copyItem(at: coreFixtures.appendingPathComponent(name), to: dir.appendingPathComponent(name))
    }
    let store = JobStore()
    store.add(files: ["danh_sach.csv", "quyet_dinh.docx"].map { dir.appendingPathComponent($0) })
    let runner = ConversionRunner(python: URL(fileURLWithPath: realPython!))
    var exit: Int32?
    store.markStarted()
    try runner.start(arguments: ConversionOptions().arguments, manifest: ConversionOptions.manifest(for: store.items),
                     onEvent: { store.apply($0) }, onExit: { status, _ in exit = status })
    await waitUntil({ exit != nil }, timeout: 120)
    #expect(exit == 0)
    #expect(store.items.map(\.status) == [.done, .done])
    #expect(store.items[0].outputs.map(\.lastPathComponent) == ["danh_sach.md"])
    let md = try String(contentsOf: dir.appendingPathComponent("danh_sach.md"), encoding: .utf8)
    #expect(md.contains("Lê Thị Hồng"))
}
