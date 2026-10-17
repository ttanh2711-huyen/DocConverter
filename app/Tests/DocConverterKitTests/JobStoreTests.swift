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
    #expect(store.items.map(\.status) == [.pending, .pending])

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
