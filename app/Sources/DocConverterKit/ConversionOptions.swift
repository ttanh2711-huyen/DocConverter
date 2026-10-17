import Foundation

/// Tuỳ chọn chuyển đổi do người dùng chọn → tham số dòng lệnh và manifest cho `docconv`.
public struct ConversionOptions: Equatable, Sendable {
    public enum PDFFormat: String, CaseIterable, Sendable {
        case markdown = "md", word = "docx", both = "md,docx"

        public var title: String {
            switch self {
            case .markdown: "Markdown (.md)"
            case .word: "Word (.docx)"
            case .both: "Cả hai"
            }
        }
    }

    public enum Location: Equatable, Sendable {
        case besideSource
        case folder(URL)
    }

    public var pdfFormat: PDFFormat
    public var location: Location

    public init(pdfFormat: PDFFormat = .markdown, location: Location = .besideSource) {
        self.pdfFormat = pdfFormat
        self.location = location
    }

    public var arguments: [String] {
        var args = ["--to", pdfFormat.rawValue]
        switch location {
        case .besideSource: args += ["--out-mode", "beside"]
        case .folder(let url): args += ["--out-mode", "dir", "--out", url.path]
        }
        return args
    }

    public static func manifest(for jobs: [JobItem]) -> Data {
        let list = jobs.map { ["src": $0.url.path, "base": $0.base.path] }
        return (try? JSONSerialization.data(withJSONObject: list)) ?? Data("[]".utf8)
    }

    // MARK: - Lưu tuỳ chọn

    public enum Keys {
        public static let pdfFormat = "pdfFormat"
        public static let outputFolder = "outputFolder"
        public static let useOutputFolder = "useOutputFolder"
        public static let trashOriginals = "trashOriginals"
        public static let trashOriginalsConfirmed = "trashOriginalsConfirmed"
    }

    public static func load(from defaults: UserDefaults = .standard) -> ConversionOptions {
        let format = defaults.string(forKey: Keys.pdfFormat).flatMap(PDFFormat.init(rawValue:)) ?? .markdown
        if defaults.bool(forKey: Keys.useOutputFolder), let path = defaults.string(forKey: Keys.outputFolder) {
            return ConversionOptions(pdfFormat: format, location: .folder(URL(fileURLWithPath: path)))
        }
        return ConversionOptions(pdfFormat: format)
    }

    public func save(to defaults: UserDefaults = .standard) {
        defaults.set(pdfFormat.rawValue, forKey: Keys.pdfFormat)
        switch location {
        case .besideSource:
            defaults.set(false, forKey: Keys.useOutputFolder)
        case .folder(let url):
            defaults.set(true, forKey: Keys.useOutputFolder)
            defaults.set(url.path, forKey: Keys.outputFolder)
        }
    }
}
