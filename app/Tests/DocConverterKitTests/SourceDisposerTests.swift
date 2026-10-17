import Foundation
import Testing
@testable import DocConverterKit

/// Thùng rác giả: ghi lại tệp được yêu cầu xoá, chuyển vào một thư mục tạm.
final class FakeTrash: @unchecked Sendable {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Thùng rác \(UUID().uuidString)")
    var trashed: [URL] = []
    var shouldFail = false

    func callAsFunction(_ url: URL) throws {
        if shouldFail { throw CocoaError(.fileWriteNoPermission) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: url, to: dir.appendingPathComponent(url.lastPathComponent))
        trashed.append(url)
    }
}

func doneItem(_ name: String, outputs: [String: String?], in dir: URL? = nil) throws -> JobItem {
    let dir = try dir ?? makeTree([])
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let src = dir.appendingPathComponent(name)
    try Data("gốc".utf8).write(to: src)
    var item = JobItem(url: src, base: dir)
    item.status = .done
    for (file, content) in outputs {
        let url = dir.appendingPathComponent(file)
        if let content { try Data(content.utf8).write(to: url) }
        item.outputs.append(url)
    }
    return item
}

@Test func trashesPdfWhenAllRequestedOutputsExist() throws {
    let item = try doneItem("a.pdf", outputs: ["a.md": "# A", "a.docx": "PK"])
    let trash = FakeTrash()
    let outcome = SourceDisposer.disposeIfSafe(item, pdfFormat: .both, trash: trash.callAsFunction)
    #expect(outcome == .trashed)
    #expect(trash.trashed == [item.url])
    #expect(!FileManager.default.fileExists(atPath: item.url.path))
    #expect(FileManager.default.fileExists(atPath: item.outputs[0].path))
}

@Test func keepsSourceWhenOneRequestedOutputIsMissing() throws {
    let item = try doneItem("a.pdf", outputs: ["a.md": "# A"])  // yêu cầu cả docx
    let trash = FakeTrash()
    let outcome = SourceDisposer.disposeIfSafe(item, pdfFormat: .both, trash: trash.callAsFunction)
    #expect(outcome == .kept("Không xoá tệp gốc: thiếu tệp kết quả .docx"))
    #expect(trash.trashed.isEmpty)
}

@Test func keepsSourceWhenOutputIsEmpty() throws {
    let item = try doneItem("a.xlsx", outputs: ["a.md": ""])
    let trash = FakeTrash()
    #expect(SourceDisposer.disposeIfSafe(item, pdfFormat: .markdown, trash: trash.callAsFunction)
            == .kept("Không xoá tệp gốc: tệp kết quả a.md rỗng"))
    #expect(trash.trashed.isEmpty)
}

@Test func keepsSourceWhenOutputFileWasRemovedOnDisk() throws {
    let item = try doneItem("a.pdf", outputs: ["a.md": nil])  // sự kiện báo có nhưng tệp không tồn tại
    let trash = FakeTrash()
    #expect(SourceDisposer.disposeIfSafe(item, pdfFormat: .markdown, trash: trash.callAsFunction)
            == .kept("Không xoá tệp gốc: thiếu tệp kết quả .md"))
}

@Test(arguments: [JobItem.Status.failed("lỗi"), .cancelled, .skipped("bỏ qua"), .pending, .running("…")])
func neverTrashesUnlessDone(status: JobItem.Status) throws {
    var item = try doneItem("a.pdf", outputs: ["a.md": "# A"])
    item.status = status
    let trash = FakeTrash()
    if case .kept = SourceDisposer.disposeIfSafe(item, pdfFormat: .markdown, trash: trash.callAsFunction) {} else {
        Issue.record("không được xoá khi trạng thái là \(status)")
    }
    #expect(trash.trashed.isEmpty)
    #expect(FileManager.default.fileExists(atPath: item.url.path))
}

@Test func neverTrashesWhenAnOutputIsTheSourceItself() throws {
    var item = try doneItem("a.md.txt", outputs: [:])
    item.outputs = [item.url]
    let trash = FakeTrash()
    #expect(SourceDisposer.disposeIfSafe(item, pdfFormat: .markdown, trash: trash.callAsFunction)
            == .kept("Không xoá tệp gốc: tệp kết quả trùng với tệp gốc"))
    #expect(trash.trashed.isEmpty)
}

@Test func nonPdfOnlyNeedsMarkdownEvenIfWordRequested() throws {
    let item = try doneItem("q.docx", outputs: ["q.md": "# Q"])
    let trash = FakeTrash()
    #expect(SourceDisposer.disposeIfSafe(item, pdfFormat: .both, trash: trash.callAsFunction) == .trashed)
}

@Test func trashFailureKeepsSourceAndReports() throws {
    let item = try doneItem("a.pdf", outputs: ["a.md": "# A"])
    let trash = FakeTrash()
    trash.shouldFail = true
    let outcome = SourceDisposer.disposeIfSafe(item, pdfFormat: .markdown, trash: trash.callAsFunction)
    guard case .kept(let message) = outcome else { Issue.record("phải giữ tệp"); return }
    #expect(message.hasPrefix("Không đưa được tệp gốc vào Thùng rác"))
    #expect(FileManager.default.fileExists(atPath: item.url.path))
}
