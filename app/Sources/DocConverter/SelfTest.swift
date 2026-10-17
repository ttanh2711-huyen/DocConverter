import AppKit
import DocConverterKit

/// Chế độ tự kiểm tra cho phát triển (không cần quyền Ghi màn hình):
///   DOCCONV_TEST_FILES="/a.pdf:/b.xlsx"  nạp các tệp và bấm "Bắt đầu"
///   DOCCONV_TEST_SNAPSHOT=/tmp/x.png    khi xong, chụp cửa sổ ra PNG rồi thoát
@MainActor
enum SelfTest {
    static let env = ProcessInfo.processInfo.environment

    static func run(_ model: AppModel) {
        guard let files = env["DOCCONV_TEST_FILES"] else { return }
        model.store.add(files: files.split(separator: ":").map { URL(fileURLWithPath: String($0)) })
        model.start()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            while model.store.isRunning { try? await Task.sleep(for: .milliseconds(200)) }
            try? await Task.sleep(for: .milliseconds(500))
            if let path = env["DOCCONV_TEST_SNAPSHOT"] { snapshot(to: URL(fileURLWithPath: path)) }
            NSApp.terminate(nil)
        }
    }

    static func snapshot(to url: URL) {
        guard let view = NSApp.windows.first(where: { $0.isVisible })?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
