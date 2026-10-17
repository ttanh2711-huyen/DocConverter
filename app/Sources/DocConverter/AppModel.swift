import DocConverterKit
import Foundation
import Observation

/// Nối JobStore với tiến trình lõi Python.
@MainActor @Observable
final class AppModel {
    let store = JobStore()
    var options = ConversionOptions()
    var alert: String?
    @ObservationIgnored private var runner: ConversionRunner?

    func start() {
        let jobs = store.pendingJobs
        guard !jobs.isEmpty, !store.isRunning else { return }
        guard let python = PythonLocator.resolve() else {
            alert = "Không tìm thấy môi trường Python của DocConverter. Hãy mở lại app để thiết lập."
            return
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
