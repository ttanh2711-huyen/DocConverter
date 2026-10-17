import Foundation

/// Một dòng sự kiện JSON từ `docconv convert --json` (xem core/PROTOCOL.md).
public struct ConversionEvent: Decodable, Sendable, Equatable {
    public enum Kind: String, Decodable, Sendable {
        case start, progress, warning, done, skipped, error, cancelled, finished
    }

    public let kind: Kind
    public var file: String?
    public var index: Int?
    public var total: Int?
    public var pages: Int?
    public var stage: String?
    public var message: String?
    public var detail: String?
    public var outputs: [String]?
    public var seconds: Double?
    public var ok: Int?
    public var failed: Int?
    public var skipped: Int?
    public var cancelled: Bool?

    enum CodingKeys: String, CodingKey {
        case kind = "event"
        case file, index, total, pages, stage, message, detail, outputs, seconds, ok, failed, skipped, cancelled
    }

    public init(kind: Kind, file: String? = nil) {
        self.kind = kind
        self.file = file
    }

    public static func decode(line: String) throws -> ConversionEvent {
        try JSONDecoder().decode(ConversionEvent.self, from: Data(line.utf8))
    }
}

/// Ghép các khối byte từ pipe thành từng dòng hoàn chỉnh (không cắt giữa ký tự UTF-8).
public struct LineBuffer: Sendable {
    private var pending = Data()

    public init() {}

    public mutating func append(_ data: Data) -> [String] {
        pending.append(data)
        var lines: [String] = []
        while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
            let line = pending[pending.startIndex..<newline]
            pending = Data(pending[pending.index(after: newline)...])
            if let text = String(data: line, encoding: .utf8), !text.isEmpty {
                lines.append(text)
            }
        }
        return lines
    }
}
