import DocConverterKit
import Foundation
import Observation

/// Nối JobStore với tiến trình lõi Python.
@MainActor @Observable
final class AppModel {
    let store = JobStore()
    /// Chỉ dùng cho chế độ tự kiểm tra; bình thường đọc tuỳ chọn người dùng đã lưu.
    var optionsOverride: ConversionOptions?
    var trashOriginalsOverride: Bool?
    var alert: String?
    @ObservationIgnored private var runner: ConversionRunner?

    func start() {
        let jobs = store.pendingJobs
        guard !jobs.isEmpty, !store.isRunning else { return }
        guard let python = PythonLocator.resolve() else {
            alert = "Không tìm thấy môi trường Python của DocConverter. Hãy mở lại app để thiết lập."
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
                onEvent: { [store] in store.apply($0) },
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
