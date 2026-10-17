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
    var alert: String?
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
        store.markStarted()
        do {
            try runner.start(
                arguments: options.arguments,
                manifest: ConversionOptions.manifest(for: jobs),
                onEvent: { [store] event in
                    // Cảnh báo "Word chỉ áp dụng cho PDF" lặp ở mọi tệp khác PDF; bảng tuỳ chọn đã ghi rõ điều này.
                    if event.kind == .warning, event.message?.contains("chỉ áp dụng cho PDF") == true { return }
                    store.apply(event)
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
