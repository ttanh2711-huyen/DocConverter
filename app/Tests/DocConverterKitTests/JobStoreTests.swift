import Foundation
import Testing
@testable import DocConverterKit

@MainActor
func ev(_ json: String) -> ConversionEvent {
    try! ConversionEvent.decode(line: json)
}

@Test @MainActor func appliesEventSequenceToJobs() {
    let store = JobStore()
    store.add(files: [URL(fileURLWithPath: "/Users/a/Tài liệu/x.pdf"), URL(fileURLWithPath: "/Users/a/Tài liệu/cu.doc")])
    #expect(store.items.map(\.status) == [.pending, .skipped("Không hỗ trợ định dạng .doc")])

    for line in protocolSample.split(separator: "\n").prefix(2) { store.apply(ev(String(line))) }
    #expect(store.items[0].status == .running("Đang phân tích bố cục (2 trang)"))

    for line in protocolSample.split(separator: "\n").dropFirst(2) { store.apply(ev(String(line))) }
    #expect(store.items[0].status == .done)
    #expect(store.items[0].outputs.map(\.lastPathComponent) == ["x.md", "x_assets", "x.docx"])
    #expect(store.items[1].status == .failed("Không hỗ trợ định dạng .doc: cu.doc"))
    #expect(store.items[1].detail == "UnsupportedFormat")
}

@Test @MainActor func warningIsKeptAsNote() {
    let store = JobStore()
    store.add(files: [URL(fileURLWithPath: "/a/q.docx")])
    store.apply(ev(#"{"event":"warning","file":"/a/q.docx","message":"chỉ áp dụng cho PDF"}"#))
    #expect(store.items[0].note == "chỉ áp dụng cho PDF")
}

@Test @MainActor func cancelledRunMarksUnfinishedJobs() {
    let store = JobStore()
    store.add(files: ["/a/1.pdf", "/a/2.pdf", "/a/3.pdf"].map { URL(fileURLWithPath: $0) })
    store.apply(ev(#"{"event":"start","file":"/a/1.pdf","index":1,"total":3}"#))
    store.apply(ev(#"{"event":"done","file":"/a/1.pdf","outputs":["/a/1.md"],"seconds":1}"#))
    store.apply(ev(#"{"event":"start","file":"/a/2.pdf","index":2,"total":3}"#))
    store.apply(ev(#"{"event":"cancelled"}"#))
    store.apply(ev(#"{"event":"finished","ok":1,"failed":0,"skipped":0,"cancelled":true}"#))
    #expect(store.items.map(\.status) == [.done, .cancelled, .cancelled])
}

@Test @MainActor func processExitWithoutFinishedMarksRunningAsFailed() {
    let store = JobStore()
    store.add(files: [URL(fileURLWithPath: "/a/1.pdf")])
    store.apply(ev(#"{"event":"start","file":"/a/1.pdf","index":1,"total":1}"#))
    store.processExited(status: 1, stderrTail: "Traceback… MemoryError")
    #expect(store.items[0].status == .failed("Tiến trình chuyển đổi dừng bất thường (mã 1)"))
    #expect(store.items[0].detail == "Traceback… MemoryError")
}

@Test func revealTargetsAreExistingFilesNotAssetFolders() throws {
    let dir = try makeTree(["x.md", "x.docx", "x_assets/img.png"])
    var item = JobItem(url: dir.appendingPathComponent("x.pdf"), base: dir)
    item.outputs = ["x.md", "x_assets", "x.docx", "da_xoa.md"].map { dir.appendingPathComponent($0) }
    #expect(item.revealTargets.map(\.lastPathComponent) == ["x.md", "x.docx"])
}

@Test @MainActor func summaryCountsAndProgress() {
    let store = JobStore()
    store.add(files: ["/a/1.pdf", "/a/2.pdf", "/a/3.xlsx", "/a/4.doc"].map { URL(fileURLWithPath: $0) })
    #expect(store.summary == JobStore.Summary(total: 4, done: 0, failed: 0, skipped: 1, cancelled: 0, active: 3))
    #expect(store.progress == 0)
    store.apply(ev(#"{"event":"done","file":"/a/1.pdf","outputs":[],"seconds":1}"#))
    store.apply(ev(#"{"event":"error","file":"/a/2.pdf","message":"x","detail":"y"}"#))
    #expect(store.summary.done == 1 && store.summary.failed == 1 && store.summary.active == 1)
    #expect(store.progress == 2.0 / 3.0)
}

@Test @MainActor func removeManyKeepsOthers() {
    let store = JobStore()
    store.add(files: ["/a/1.pdf", "/a/2.pdf", "/a/3.pdf"].map { URL(fileURLWithPath: $0) })
    store.remove(Set(["/a/1.pdf", "/a/3.pdf"]))
    #expect(store.items.map(\.url.lastPathComponent) == ["2.pdf"])
}
