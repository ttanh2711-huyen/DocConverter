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

    /// Tuỳ chọn nhận dạng chữ (OCR) và bảng cho PDF.
    public struct OCR: Equatable, Sendable {
        public enum Mode: String, CaseIterable, Sendable {
            case auto, off, force

            public var title: String {
                switch self {
                case .auto: "Tự động (chỉ trang không có chữ)"
                case .off: "Tắt"
                case .force: "Luôn nhận dạng mọi trang"
                }
            }
        }

        public enum Engine: String, CaseIterable, Sendable {
            case ocrmac, easyocr

            public var title: String {
                switch self {
                case .ocrmac: "Apple Vision (khuyên dùng)"
                case .easyocr: "EasyOCR"
                }
            }
        }

        public var mode: Mode = .auto
        public var engine: Engine = .ocrmac
        public var tables = true

        public init(mode: Mode = .auto, engine: Engine = .ocrmac, tables: Bool = true) {
            self.mode = mode
            self.engine = engine
            self.tables = tables
        }
    }

    public var pdfFormat: PDFFormat
    public var location: Location
    public var ocr = OCR()
    /// Sổ tổng hợp Excel ghi thông tin văn bản; `nil` là không ghi.
    public var register: URL?

    public init(pdfFormat: PDFFormat = .markdown, location: Location = .besideSource, register: URL? = nil) {
        self.pdfFormat = pdfFormat
        self.location = location
        self.register = register
    }

    /// Sổ mặc định: ~/Documents/Tổng hợp văn bản.xlsx
    public static var defaultRegister: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tổng hợp văn bản.xlsx")
    }

    public var arguments: [String] {
        var args = ["--to", pdfFormat.rawValue]
        switch location {
        case .besideSource: args += ["--out-mode", "beside"]
        case .folder(let url): args += ["--out-mode", "dir", "--out", url.path]
        }
        if ocr.mode != .auto { args += ["--ocr", ocr.mode.rawValue] }
        if ocr.engine != .ocrmac { args += ["--ocr-engine", ocr.engine.rawValue] }
        if !ocr.tables { args.append("--no-tables") }
        if let register { args += ["--register", register.path] }
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
        public static let ocrMode = "ocrMode"
        public static let ocrEngine = "ocrEngine"
        public static let ocrTables = "ocrTables"
        public static let registerEnabled = "registerEnabled"
        public static let registerPath = "registerPath"
    }

    public static func load(from defaults: UserDefaults = .standard) -> ConversionOptions {
        let format = defaults.string(forKey: Keys.pdfFormat).flatMap(PDFFormat.init(rawValue:)) ?? .markdown
        var options = ConversionOptions(pdfFormat: format)
        if defaults.bool(forKey: Keys.useOutputFolder), let path = defaults.string(forKey: Keys.outputFolder) {
            options.location = .folder(URL(fileURLWithPath: path))
        }
        options.ocr = OCR(
            mode: defaults.string(forKey: Keys.ocrMode).flatMap(OCR.Mode.init(rawValue:)) ?? .auto,
            engine: defaults.string(forKey: Keys.ocrEngine).flatMap(OCR.Engine.init(rawValue:)) ?? .ocrmac,
            tables: defaults.object(forKey: Keys.ocrTables) as? Bool ?? true)
        if defaults.object(forKey: Keys.registerEnabled) as? Bool ?? true {
            let path = defaults.string(forKey: Keys.registerPath) ?? ""
            options.register = path.isEmpty ? defaultRegister : URL(fileURLWithPath: path)
        }
        return options
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
        defaults.set(ocr.mode.rawValue, forKey: Keys.ocrMode)
        defaults.set(ocr.engine.rawValue, forKey: Keys.ocrEngine)
        defaults.set(ocr.tables, forKey: Keys.ocrTables)
        defaults.set(register != nil, forKey: Keys.registerEnabled)
        if let register { defaults.set(register.path, forKey: Keys.registerPath) }
    }
}
