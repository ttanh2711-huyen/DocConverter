import AppKit
import SwiftUI

@main
struct DocConverterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("DocConverter", id: "main") {
            ContentView(model: delegate.model)
        }
        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor let model = AppModel()

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !MainActor.assumeIsolated { model.store.isRunning }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            guard model.store.isRunning else { return .terminateNow }
            let alert = NSAlert()
            alert.messageText = "Đang chuyển đổi"
            alert.informativeText = "Thoát bây giờ sẽ huỷ các tệp đang chuyển. Tệp dở dang sẽ được dọn sạch."
            alert.addButton(withTitle: "Huỷ và thoát")
            alert.addButton(withTitle: "Tiếp tục chuyển đổi")
            guard alert.runModal() == .alertFirstButtonReturn else { return .terminateCancel }
            model.cancel()
            Task { @MainActor in
                // Chờ lõi dọn dẹp xong (tối đa 10 giây) rồi mới thoát.
                for _ in 0..<50 where model.store.isRunning { try? await Task.sleep(for: .milliseconds(200)) }
                sender.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        }
    }
}
