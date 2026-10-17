import Foundation
import Testing
@testable import DocConverterKit

func makeTree(_ paths: [String]) throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("Đầu vào \(UUID().uuidString)")
    for p in paths {
        let url = root.appendingPathComponent(p)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: url)
    }
    return root
}

@Test func folderNonRecursiveTakesTopLevelOnly() throws {
    let root = try makeTree(["a.pdf", "b.xlsx", "sub/c.docx", ".an.pdf", "cu.doc"])
    let entries = InputCollector.expand([root], recursive: false)
    #expect(entries.map(\.url.lastPathComponent) == ["a.pdf", "b.xlsx", "cu.doc"])
    #expect(entries.allSatisfy { $0.base == root.standardizedFileURL })
    #expect(entries.map(\.supported) == [true, true, false])
}

@Test func folderRecursiveKeepsBaseAndSkipsHidden() throws {
    let root = try makeTree(["a.pdf", "sub/c.docx", "sub/.git/x.pdf", "sub/deep/d.HTML"])
    let entries = InputCollector.expand([root], recursive: true)
    #expect(entries.map { $0.url.path.replacingOccurrences(of: root.standardizedFileURL.path + "/", with: "") }
            == ["a.pdf", "sub/c.docx", "sub/deep/d.HTML"])
    #expect(entries.allSatisfy { $0.base == root.standardizedFileURL && $0.supported })
}

@Test func filesUseTheirParentAsBase() throws {
    let root = try makeTree(["x/a.pdf"])
    let file = root.appendingPathComponent("x/a.pdf")
    let entries = InputCollector.expand([file], recursive: true)
    #expect(entries.count == 1)
    #expect(entries[0].base == file.deletingLastPathComponent().standardizedFileURL)
}

@Test @MainActor func storeDedupesAndMarksUnsupportedAsSkipped() throws {
    let root = try makeTree(["a.pdf", "cu.doc"])
    let store = JobStore()
    store.add(InputCollector.expand([root], recursive: false))
    store.add(InputCollector.expand([root.appendingPathComponent("a.pdf")], recursive: false))
    #expect(store.items.count == 2)
    #expect(store.items[1].status == .skipped("Không hỗ trợ định dạng .doc"))
    #expect(store.pendingJobs.map(\.url.lastPathComponent) == ["a.pdf"])
}
