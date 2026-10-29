import Foundation

/// Một dòng sự kiện JSON từ `docconv convert --json` (xem core/PROTOCOL.md).
public struct ConversionEvent: Decodable, Sendable, Equatable {
    public enum Kind: String, Decodable, Sendable {
        case start, progress, warning, done, skipped, error, cancelled, register, finished
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
    /// `done`: thông tin văn bản nhận ra được.
    public var meta: DocumentMeta?
    /// `register`: sổ tổng hợp đã ghi (hoặc lỗi).
    public var path: String?
    public var added: Int?
    public var updated: Int?
    public var error: String?

    enum CodingKeys: String, CodingKey {
        case kind = "event"
        case file, index, total, pages, stage, message, detail, outputs, seconds, ok, failed, skipped, cancelled
        case meta, path, added, updated, error
    }

    public init(kind: Kind, file: String? = nil) {
        self.kind = kind
        self.file = file
    }

    public static func decode(line: String) throws -> ConversionEvent {
        try JSONDecoder().decode(ConversionEvent.self, from: Data(line.utf8))
    }
}

/// Thông tin văn bản hành chính do lõi trích ra (trường nào không nhận ra thì `nil`).
public struct DocumentMeta: Decodable, Sendable, Equatable {
    public var docType: String?
    public var number: String?
    public var date: String?
    public var issuer: String?
    public var signer: String?
    public var position: String?
    public var summary: String?

    enum CodingKeys: String, CodingKey {
        case docType = "doc_type"
        case number, date, issuer, signer, position, summary
    }

    public init(docType: String? = nil, number: String? = nil, date: String? = nil, issuer: String? = nil,
                signer: String? = nil, position: String? = nil, summary: String? = nil) {
        self.docType = docType
        self.number = number
        self.date = date
        self.issuer = issuer
        self.signer = signer
        self.position = position
        self.summary = summary
    }

    /// Đủ dấu hiệu là văn bản hành chính để lõi ghi vào sổ (cùng quy tắc với `DocMeta.is_document`).
    public var isDocument: Bool {
        number != nil || (docType != nil && (date != nil || signer != nil))
    }

    /// "2026-03-15" → "15/03/2026".
    public var displayDate: String? {
        guard let date else { return nil }
        let parts = date.split(separator: "-")
        return parts.count == 3 ? "\(parts[2])/\(parts[1])/\(parts[0])" : date
    }

    /// Một dòng tóm tắt: "Quyết định 12/QĐ-UBND · 15/03/2026 · Nguyễn Văn Bình".
    public var headline: String {
        let title = [docType, number].compactMap { $0 }.joined(separator: " ")
        return [title.isEmpty ? nil : title, displayDate, signer].compactMap { $0 }.joined(separator: " · ")
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
