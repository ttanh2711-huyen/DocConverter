import Foundation
import Testing
@testable import DocConverterKit

/// Các dòng mẫu lấy nguyên văn từ core/PROTOCOL.md.
let protocolSample = """
{"event": "start", "file": "/Users/a/Tài liệu/x.pdf", "index": 1, "total": 2, "kind": "pdf", "pages": 2}
{"event": "progress", "file": "/Users/a/Tài liệu/x.pdf", "stage": "analyze", "message": "Đang phân tích bố cục (2 trang)"}
{"event": "progress", "file": "/Users/a/Tài liệu/x.pdf", "stage": "markdown", "message": "Đang ghi Markdown"}
{"event": "progress", "file": "/Users/a/Tài liệu/x.pdf", "stage": "docx", "message": "Đang tạo Word"}
{"event": "done", "file": "/Users/a/Tài liệu/x.pdf", "outputs": ["/Users/a/Tài liệu/x.md", "/Users/a/Tài liệu/x_assets", "/Users/a/Tài liệu/x.docx"], "seconds": 12.4}
{"event": "start", "file": "/Users/a/Tài liệu/cu.doc", "index": 2, "total": 2, "kind": null, "pages": null}
{"event": "error", "file": "/Users/a/Tài liệu/cu.doc", "message": "Không hỗ trợ định dạng .doc: cu.doc", "detail": "UnsupportedFormat"}
{"event": "finished", "ok": 1, "failed": 1, "skipped": 0, "cancelled": false}
"""

@Test func decodesEveryProtocolSampleLine() throws {
    let events = try protocolSample.split(separator: "\n").map { try ConversionEvent.decode(line: String($0)) }
    #expect(events.map(\.kind) == [.start, .progress, .progress, .progress, .done, .start, .error, .finished])
    #expect(events[0].file == "/Users/a/Tài liệu/x.pdf")
    #expect(events[0].pages == 2 && events[0].total == 2)
    #expect(events[4].outputs?.count == 3)
    #expect(events[6].message == "Không hỗ trợ định dạng .doc: cu.doc")
    #expect(events[7].cancelled == false && events[7].ok == 1)
}

@Test func lineBufferSplitsChunksAcrossBoundaries() {
    var buffer = LineBuffer()
    let data = Data("{\"a\":1}\n{\"b\":".utf8)
    #expect(buffer.append(data) == ["{\"a\":1}"])
    #expect(buffer.append(Data("2}\n".utf8)) == ["{\"b\":2}"])
    #expect(buffer.append(Data()) == [])
}

@Test func lineBufferKeepsMultibyteUTF8SplitAcrossChunks() {
    var buffer = LineBuffer()
    let bytes = Array("Tài liệu\n".utf8)
    let cut = 2  // cắt giữa ký tự "à" (2 byte)
    #expect(buffer.append(Data(bytes[..<cut])) == [])
    #expect(buffer.append(Data(bytes[cut...])) == ["Tài liệu"])
}
