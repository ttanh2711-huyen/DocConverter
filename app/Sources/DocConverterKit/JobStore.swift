import Foundation
import Observation

public struct JobItem: Identifiable, Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case pending
        case running(String)
        case done
        case failed(String)
        case skipped(String)
        case cancelled
    }

    public var id: String { url.path }
    public let url: URL
    /// Thư mục gốc để giữ cấu trúc thư mục con khi lưu vào thư mục khác.
    public let base: URL
    public var status: Status = .pending
    public var outputs: [URL] = []
    public var note: String?
    public var detail: String?
    public var sourceTrashed = false

    public init(url: URL, base: URL) {
        self.url = url
        self.base = base
    }

    public var isFinished: Bool {
        switch status {
        case .done, .failed, .skipped, .cancelled: true
        case .pending, .running: false
        }
    }
}

/// Danh sách tệp cần chuyển và trạng thái của từng tệp, cập nhật theo sự kiện từ lõi.
@MainActor @Observable
public final class JobStore {
    public private(set) var items: [JobItem] = []
    public private(set) var isRunning = false
    /// Gọi khi một tệp xong (để app xử lý tiếp, ví dụ đưa bản gốc vào Thùng rác).
    @ObservationIgnored public var onJobDone: ((JobItem) -> Void)?

    public init() {}

    public func add(files: [URL]) {
        add(files.map { InputEntry(url: $0.standardizedFileURL, base: $0.standardizedFileURL.deletingLastPathComponent()) })
    }

    public func add(_ entries: [InputEntry]) {
        var existing = Set(items.map(\.id))
        for entry in entries where !existing.contains(entry.url.path) {
            existing.insert(entry.url.path)
            var item = JobItem(url: entry.url, base: entry.base)
            if !entry.supported {
                let ext = entry.url.pathExtension.isEmpty ? "(không có đuôi)" : ".\(entry.url.pathExtension)"
                item.status = .skipped("Không hỗ trợ định dạng \(ext)")
            }
            items.append(item)
        }
    }

    public func remove(_ id: JobItem.ID) {
        guard !isRunning else { return }
        items.removeAll { $0.id == id }
    }

    /// Các tệp sẽ gửi cho lõi ở lần chạy tới.
    public var pendingJobs: [JobItem] {
        items.filter {
            switch $0.status {
            case .done, .skipped: false
            default: true
            }
        }
    }

    public func clear() {
        guard !isRunning else { return }
        items.removeAll()
    }

    public func update(_ id: JobItem.ID, _ change: (inout JobItem) -> Void) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[i])
    }

    public func markStarted() {
        isRunning = true
        for i in items.indices {
            switch items[i].status {
            case .failed, .cancelled: items[i].status = .pending  // chạy lại các tệp lỗi/huỷ
            default: break
            }
        }
    }

    public func apply(_ event: ConversionEvent) {
        let id = event.file.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        switch event.kind {
        case .start:
            if let id { update(id) { $0.status = .running("Đang chuẩn bị…"); $0.detail = nil } }
        case .progress:
            if let id { update(id) { $0.status = .running(event.message ?? "Đang xử lý…") } }
        case .warning:
            if let id { update(id) { $0.note = event.message } }
        case .done:
            if let id {
                update(id) {
                    $0.status = .done
                    $0.outputs = (event.outputs ?? []).map { URL(fileURLWithPath: $0) }
                }
                if let item = items.first(where: { $0.id == id }) { onJobDone?(item) }
            }
        case .skipped:
            if let id { update(id) { $0.status = .skipped(event.message ?? "Bỏ qua") } }
        case .error:
            if let id { update(id) { $0.status = .failed(event.message ?? "Lỗi"); $0.detail = event.detail } }
        case .cancelled, .finished:
            if event.kind == .cancelled || event.cancelled == true {
                for i in items.indices where !items[i].isFinished { items[i].status = .cancelled }
            }
            if event.kind == .finished { isRunning = false }
        }
    }

    /// Tiến trình kết thúc. Nếu chưa có `finished` (Python bị crash), đánh dấu các tệp dở dang là lỗi.
    public func processExited(status: Int32, stderrTail: String) {
        for i in items.indices where !items[i].isFinished {
            if status == 130, items[i].status == .pending {
                items[i].status = .cancelled
            } else {
                items[i].status = .failed("Tiến trình chuyển đổi dừng bất thường (mã \(status))")
                items[i].detail = stderrTail
            }
        }
        isRunning = false
    }
}
