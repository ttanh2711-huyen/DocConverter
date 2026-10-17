import AppKit
import DocConverterKit

/// Chế độ tự kiểm tra cho phát triển (không cần quyền Ghi màn hình):
///   DOCCONV_TEST_FILES="/a.pdf:/thư mục"  nạp tệp/thư mục (thư mục con: DOCCONV_TEST_RECURSIVE=0 để tắt)
///                                        rồi bấm "Bắt đầu"
///   DOCCONV_TEST_SNAPSHOT=/tmp/x.png    khi xong, chụp cửa sổ ra PNG rồi thoát
@MainActor
enum SelfTest {
    static let env = ProcessInfo.processInfo.environment

    static func run(_ model: AppModel) {
        guard let files = env["DOCCONV_TEST_FILES"] else { return }
        let urls = files.split(separator: ":").map { URL(fileURLWithPath: String($0)) }
        model.store.add(InputCollector.expand(urls, recursive: env["DOCCONV_TEST_RECURSIVE"] != "0"))
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
        guard let window = NSApp.windows.first(where: { $0.isVisible }),
              let view = window.contentView?.superview ?? window.contentView,
              let layer = view.layer else { return }
        let scale = window.backingScaleFactor
        let size = view.bounds.size
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
                                         pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0),
              let ctx = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else { return }
        ctx.scaleBy(x: scale, y: scale)
        ctx.setFillColor(NSColor.windowBackgroundColor.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        layer.render(in: ctx)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
