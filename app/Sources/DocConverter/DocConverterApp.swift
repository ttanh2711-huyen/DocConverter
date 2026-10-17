import AppKit
import DocConverterKit
import SwiftUI

@main
struct DocConverterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("DocConverter", id: "main") {
            ContentView(model: delegate.model)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1040, height: 660)
        .commands { AppCommands(model: delegate.model) }
        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor let model = AppModel()

    /// Tệp/thư mục được thả lên biểu tượng app hoặc mở bằng "Mở bằng → DocConverter".
    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated {
            let recursive = UserDefaults.standard.object(forKey: "includeSubfolders") as? Bool ?? true
            model.store.add(InputCollector.expand(urls, recursive: recursive))
        }
    }

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

/// Menu và phím tắt.
struct AppCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Thêm tệp…") { model.chooseFiles() }
                .keyboardShortcut("o")
                .disabled(model.store.isRunning || !model.isReady)
            Button("Thêm thư mục…") { model.chooseFolders() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(model.store.isRunning || !model.isReady)
        }
        CommandMenu("Chuyển đổi") {
            Button("Bắt đầu") { model.start() }
                .keyboardShortcut("r")
                .disabled(!model.canStart)
            Button("Huỷ") { model.cancel() }
                .keyboardShortcut(".")
                .disabled(!model.store.isRunning)
            Divider()
            Button("Xoá mục đã chọn") { model.removeSelected() }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(model.selection.isEmpty || model.store.isRunning)
            Button("Xoá danh sách") { model.clearList() }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .disabled(!model.canEditList)
        }
        CommandGroup(before: .sidebar) {
            Button(model.showInspector ? "Ẩn tuỳ chọn" : "Hiện tuỳ chọn") { model.showInspector.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .option])
            Divider()
        }
    }
}
