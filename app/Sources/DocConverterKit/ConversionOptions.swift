import Foundation

/// Tuỳ chọn chuyển đổi do người dùng chọn → tham số dòng lệnh và manifest cho `docconv`.
public struct ConversionOptions: Equatable, Sendable {
    public enum PDFFormat: String, CaseIterable, Sendable {
        case markdown = "md", word = "docx", both = "md,docx"
    }

    public var pdfFormat: PDFFormat = .markdown

    public init(pdfFormat: PDFFormat = .markdown) {
        self.pdfFormat = pdfFormat
    }

    public var arguments: [String] {
        ["--to", pdfFormat.rawValue]
    }

    public static func manifest(for jobs: [JobItem]) -> Data {
        let list = jobs.map { ["src": $0.url.path, "base": $0.base.path] }
        return (try? JSONSerialization.data(withJSONObject: list)) ?? Data("[]".utf8)
    }
}
