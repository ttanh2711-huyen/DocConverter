import Foundation

/// Đưa tệp gốc vào Thùng rác — chỉ khi chắc chắn mọi kết quả đã được tạo.
public enum SourceDisposer {
    public enum Outcome: Equatable, Sendable {
        case trashed
        case kept(String)
    }

    public static func moveToTrash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    /// Đuôi các tệp kết quả bắt buộc phải có trước khi xoá tệp gốc.
    public static func requiredExtensions(for source: URL, pdfFormat: ConversionOptions.PDFFormat) -> [String] {
        guard source.pathExtension.lowercased() == "pdf" else { return ["md"] }
        return pdfFormat.rawValue.split(separator: ",").map(String.init)
    }

    public static func disposeIfSafe(_ item: JobItem, pdfFormat: ConversionOptions.PDFFormat,
                                     trash: (URL) throws -> Void = moveToTrash) -> Outcome {
        guard item.status == .done else { return .kept("Không xoá tệp gốc: chuyển đổi chưa thành công") }
        let source = item.url.standardizedFileURL
        let outputs = item.outputs.map(\.standardizedFileURL)
        if outputs.contains(source) { return .kept("Không xoá tệp gốc: tệp kết quả trùng với tệp gốc") }

        for ext in requiredExtensions(for: source, pdfFormat: pdfFormat) {
            guard let output = outputs.first(where: {
                $0.pathExtension.lowercased() == ext && FileManager.default.fileExists(atPath: $0.path)
            }) else {
                return .kept("Không xoá tệp gốc: thiếu tệp kết quả .\(ext)")
            }
            let size = (try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if size == 0 { return .kept("Không xoá tệp gốc: tệp kết quả \(output.lastPathComponent) rỗng") }
        }
        guard FileManager.default.fileExists(atPath: source.path) else {
            return .kept("Không xoá tệp gốc: không còn tìm thấy tệp")
        }
        do {
            try trash(source)
            return .trashed
        } catch {
            return .kept("Không đưa được tệp gốc vào Thùng rác: \(error.localizedDescription)")
        }
    }
}
