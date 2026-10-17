import Foundation

/// Đuôi tệp lõi hỗ trợ — giữ đồng bộ với `core/src/docconv/router.py`.
public enum SupportedFormats {
    public static let markitdown: Set<String> = [
        "docx", "pptx", "xlsx", "xls", "html", "htm", "csv", "json", "xml", "txt",
        "epub", "zip", "msg", "jpg", "jpeg", "png",
    ]
    public static let all: Set<String> = markitdown.union(["pdf"])

    public static func isSupported(_ url: URL) -> Bool {
        all.contains(url.pathExtension.lowercased())
    }
}

public struct InputEntry: Equatable, Sendable {
    public let url: URL
    public let base: URL
    public var supported: Bool { SupportedFormats.isSupported(url) }
}

/// Biến các tệp/thư mục người dùng chọn hoặc kéo thả thành danh sách tệp kèm thư mục gốc.
public enum InputCollector {
    public static func expand(_ urls: [URL], recursive: Bool) -> [InputEntry] {
        var result: [InputEntry] = []
        for url in urls.map(\.standardizedFileURL) {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            if !isDir.boolValue {
                result.append(InputEntry(url: url, base: url.deletingLastPathComponent()))
                continue
            }
            var options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
            if !recursive { options.insert(.skipsSubdirectoryDescendants) }
            let files = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey],
                                                       options: options)?
                .compactMap { $0 as? URL }
                .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
                .map(\.standardizedFileURL)
                .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending } ?? []
            result += files.map { InputEntry(url: $0, base: url) }
        }
        return result
    }
}
