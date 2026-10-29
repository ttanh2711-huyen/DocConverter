import AppKit
import DocConverterKit
import Foundation
import Observation
import UniformTypeIdentifiers

/// Trạng thái app và các thao tác dùng chung cho thanh công cụ, menu và phím tắt.
@MainActor @Observable
final class AppModel {
    let store = JobStore()
    let environment = EnvironmentManager.forApp()
    var selection = Set<JobItem.ID>()
    var showInspector = true
    /// Bộ lọc danh sách (thanh trên danh sách và các số đếm ở thanh dưới).
    var filter = ListFilter.all
    var alert: String?
    /// Lúc sổ tổng hợp vừa ghi xong: các con dấu "VÀO SỔ" chỉ chạy hiệu ứng ngay sau thời điểm này.
    var registeredAt: Date?
    /// Chỉ dùng cho chế độ tự kiểm tra; bình thường đọc tuỳ chọn người dùng đã lưu.
    var optionsOverride: ConversionOptions?
    var trashOriginalsOverride: Bool?
    @ObservationIgnored private var runner: ConversionRunner?

    var isReady: Bool {
        if case .ready = environment.state { true } else { false }
    }

    var canStart: Bool { isReady && !store.isRunning && !store.pendingJobs.isEmpty }
    var canEditList: Bool { !store.isRunning && !store.items.isEmpty }

    // MARK: - Đầu vào

    var includeSubfolders: Bool {
        UserDefaults.standard.object(forKey: "includeSubfolders") as? Bool ?? true
    }

    func add(_ urls: [URL]) {
        guard !store.isRunning else { return }
        store.add(InputCollector.expand(urls, recursive: includeSubfolders))
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.title = "Chọn tệp cần chuyển đổi"
        panel.prompt = "Thêm"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = SupportedFormats.all.compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK { add(panel.urls) }
    }

    func chooseFolders() {
        let panel = NSOpenPanel()
        panel.title = "Chọn thư mục cần chuyển đổi"
        panel.prompt = "Thêm"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK { add(panel.urls) }
    }

    func removeSelected() {
        store.remove(selection)
        selection.removeAll()
    }

    func clearList() {
        store.clear()
        selection.removeAll()
        filter = .all
    }

    /// Xoá các tệp đã xong (hoặc bị bỏ qua), giữ lại tệp lỗi/đang chờ để chạy tiếp.
    func removeFinished(including statuses: (JobItem.Status) -> Bool) {
        let ids = Set(store.items.filter { statuses($0.status) }.map(\.id))
        store.remove(ids)
        selection.subtract(ids)
        if filter.count(in: store.summary) == 0 { filter = .all }
    }

    // MARK: - Kết quả

    var allOutputs: [URL] { store.items.flatMap(\.revealTargets) }

    func revealAllOutputs() {
        let targets = allOutputs
        if !targets.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(targets) }
    }

    /// Chọn thư mục lưu kết quả; huỷ khi chưa từng chọn thì quay về "Cạnh tệp gốc".
    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Chọn thư mục lưu kết quả"
        panel.prompt = "Chọn"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        let defaults = UserDefaults.standard
        if let current = defaults.string(forKey: ConversionOptions.Keys.outputFolder), !current.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: current)
        }
        if panel.runModal() == .OK, let url = panel.url {
            defaults.set(url.path, forKey: ConversionOptions.Keys.outputFolder)
            defaults.set(true, forKey: ConversionOptions.Keys.useOutputFolder)
        } else if (defaults.string(forKey: ConversionOptions.Keys.outputFolder) ?? "").isEmpty {
            defaults.set(false, forKey: ConversionOptions.Keys.useOutputFolder)
        }
    }

    // MARK: - Sổ tổng hợp

    /// Sổ Excel đang dùng (theo tuỳ chọn), `nil` khi tắt ghi sổ.
    var registerURL: URL? {
        ConversionOptions.load().register
    }

    func openRegister() {
        guard let url = store.register?.url ?? registerURL else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            alert = "Sổ \(url.lastPathComponent) chưa có. Sổ được tạo sau lần chuyển đổi đầu tiên có văn bản hành chính."
        }
    }

    /// Chọn sổ có sẵn (`existing`) hoặc đặt tên sổ mới.
    func chooseRegister(existing: Bool) {
        let current = registerURL ?? ConversionOptions.defaultRegister
        let url: URL?
        if existing {
            let panel = NSOpenPanel()
            panel.title = "Chọn sổ tổng hợp có sẵn"
            panel.message = "Văn bản mới sẽ được ghi thêm vào sổ; dữ liệu cũ được giữ nguyên."
            panel.prompt = "Dùng sổ này"
            panel.allowedContentTypes = [UTType(filenameExtension: "xlsx")].compactMap { $0 }
            panel.directoryURL = current.deletingLastPathComponent()
            url = panel.runModal() == .OK ? panel.url : nil
        } else {
            let panel = NSSavePanel()
            panel.title = "Tạo sổ tổng hợp mới"
            panel.prompt = "Tạo"
            panel.allowedContentTypes = [UTType(filenameExtension: "xlsx")].compactMap { $0 }
            panel.nameFieldStringValue = "Tổng hợp văn bản.xlsx"
            panel.directoryURL = current.deletingLastPathComponent()
            panel.canCreateDirectories = true
            url = panel.runModal() == .OK ? panel.url : nil
        }
        guard let url else { return }
        UserDefaults.standard.set(url.path, forKey: ConversionOptions.Keys.registerPath)
        UserDefaults.standard.set(true, forKey: ConversionOptions.Keys.registerEnabled)
    }

    /// Con dấu nên chạy hiệu ứng (vừa ghi sổ xong, chưa quá 2 giây).
    var stampIsFresh: Bool {
        registeredAt.map { Date.now.timeIntervalSince($0) < 2 } ?? false
    }

    /// Số tệp sẽ chạy khi bấm Bắt đầu, và có phải tất cả đều là chạy lại (lỗi/huỷ) không.
    var startCount: (count: Int, isRetry: Bool) {
        let jobs = store.pendingJobs
        return (jobs.count, !jobs.isEmpty && jobs.allSatisfy { $0.status != .pending })
    }

    // MARK: - Chuyển đổi

    func start() {
        let jobs = store.pendingJobs
        guard !jobs.isEmpty, !store.isRunning else { return }
        guard case .ready(let python) = environment.state else {
            alert = "Môi trường chuyển đổi chưa sẵn sàng."
            return
        }
        let options = optionsOverride ?? ConversionOptions.load()
        if case .folder(let url) = options.location, !FileManager.default.fileExists(atPath: url.path) {
            alert = "Thư mục lưu kết quả không tồn tại: \(url.path)"
            return
        }
        let trashOriginals = trashOriginalsOverride
            ?? UserDefaults.standard.bool(forKey: ConversionOptions.Keys.trashOriginals)
        store.onJobDone = { [store] item in
            guard trashOriginals else { return }
            switch SourceDisposer.disposeIfSafe(item, pdfFormat: options.pdfFormat) {
            case .trashed: store.update(item.id) { $0.sourceTrashed = true }
            case .kept(let reason): store.update(item.id) { $0.note = reason }
            }
        }
        let runner = ConversionRunner(python: python)
        self.runner = runner
        filter = .all
        store.markStarted()
        do {
            try runner.start(
                arguments: options.arguments,
                manifest: ConversionOptions.manifest(for: jobs),
                onEvent: { [store, weak self] event in
                    // Cảnh báo "Word chỉ áp dụng cho PDF" lặp ở mọi tệp khác PDF; bảng tuỳ chọn đã ghi rõ điều này.
                    if event.kind == .warning, event.message?.contains("chỉ áp dụng cho PDF") == true { return }
                    store.apply(event)
                    if event.kind == .register, event.error == nil { self?.registeredAt = .now }
                    if event.kind == .register, let error = event.error {
                        self?.alert = error + "\nTệp kết quả vẫn được tạo bình thường. Nếu sổ đang mở trong Excel, hãy đóng lại rồi chạy lại."
                    }
                },
                onExit: { [store] status, tail in store.processExited(status: status, stderrTail: tail) })
        } catch {
            store.processExited(status: -1, stderrTail: error.localizedDescription)
            alert = "Không khởi chạy được tiến trình chuyển đổi: \(error.localizedDescription)"
        }
    }

    func cancel() {
        runner?.cancel()
    }
}

/// Bộ lọc danh sách tệp.
enum ListFilter: String, CaseIterable, Identifiable {
    case all, active, done, issues

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "Tất cả"
        case .active: "Đang chờ"
        case .done: "Hoàn tất"
        case .issues: "Lỗi"
        }
    }

    func includes(_ status: JobItem.Status) -> Bool {
        switch (self, status) {
        case (.all, _), (.active, .pending), (.active, .running), (.done, .done),
             (.issues, .failed), (.issues, .cancelled), (.issues, .skipped): true
        default: false
        }
    }

    func count(in s: JobStore.Summary) -> Int {
        switch self {
        case .all: s.total
        case .active: s.active
        case .done: s.done
        case .issues: s.failed + s.cancelled + s.skipped
        }
    }
}
