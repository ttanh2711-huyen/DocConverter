import AppKit
import DocConverterKit

/// Chế độ tự kiểm tra cho phát triển (không cần quyền Ghi màn hình):
///   DOCCONV_TEST_FILES="/a.pdf:/thư mục"  nạp tệp/thư mục (thư mục con: DOCCONV_TEST_RECURSIVE=0 để tắt)
///                                        rồi bấm "Bắt đầu"
///   DOCCONV_TEST_FORMAT=md|docx|md,docx  định dạng cho PDF;  DOCCONV_TEST_OUT=/thư/mục  lưu vào thư mục khác
///   DOCCONV_TEST_CANCEL_AFTER=3          bấm "Huỷ" sau 3 giây
///   DOCCONV_TEST_OCR=auto|off|force, DOCCONV_TEST_OCR_ENGINE=ocrmac|easyocr
///   DOCCONV_TEST_TRASH=1                 bật "Xoá tệp gốc" cho lần chạy này
///   DOCCONV_TEST_SNAPSHOT=/tmp/x.png    khi xong, chụp cửa sổ ra PNG rồi thoát (không có FILES: chụp màn hình trống)
///   DOCCONV_TEST_SNAPSHOT_RUNNING=/tmp/r.png  chụp khi đang chạy (sau DOCCONV_TEST_RUNNING_AFTER giây, mặc định 6)
@MainActor
enum SelfTest {
    static let env = ProcessInfo.processInfo.environment

    private static var started = false

    static func run(_ model: AppModel) {
        guard !started else { return }
        guard let files = env["DOCCONV_TEST_FILES"] else {
            // Chỉ chụp màn hình trống.
            if let path = env["DOCCONV_TEST_SNAPSHOT"] {
                started = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1200))
                    snapshot(to: URL(fileURLWithPath: path))
                    NSApp.terminate(nil)
                }
            }
            return
        }
        started = true
        let urls = files.split(separator: ":").map { URL(fileURLWithPath: String($0)) }
        model.store.add(InputCollector.expand(urls, recursive: env["DOCCONV_TEST_RECURSIVE"] != "0"))
        var options = ConversionOptions.load()
        if let f = env["DOCCONV_TEST_FORMAT"].flatMap(ConversionOptions.PDFFormat.init(rawValue:)) { options.pdfFormat = f }
        if let out = env["DOCCONV_TEST_OUT"] { options.location = .folder(URL(fileURLWithPath: out)) }
        if let m = env["DOCCONV_TEST_OCR"].flatMap(ConversionOptions.OCR.Mode.init(rawValue:)) { options.ocr.mode = m }
        if let e = env["DOCCONV_TEST_OCR_ENGINE"].flatMap(ConversionOptions.OCR.Engine.init(rawValue:)) {
            options.ocr.engine = e
        }
        model.optionsOverride = options
        model.trashOriginalsOverride = env["DOCCONV_TEST_TRASH"] == "1"
        model.start()
        if let path = env["DOCCONV_TEST_SNAPSHOT_RUNNING"] {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Double(env["DOCCONV_TEST_RUNNING_AFTER"] ?? "6") ?? 6))
                snapshot(to: URL(fileURLWithPath: path))
            }
        }
        if let after = env["DOCCONV_TEST_CANCEL_AFTER"].flatMap(Double.init) {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(after))
                model.cancel()
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            while model.store.isRunning { try? await Task.sleep(for: .milliseconds(200)) }
            try? await Task.sleep(for: .milliseconds(500))
            if let path = env["DOCCONV_TEST_SNAPSHOT"] { snapshot(to: URL(fileURLWithPath: path)) }
            NSApp.terminate(nil)
        }
    }

    /// DOCCONV_TEST_SNAPSHOT mà không có DOCCONV_TEST_FILES: chụp màn hình thiết lập rồi thoát.
    static func snapshotSetupScreen() {
        guard env["DOCCONV_TEST_FILES"] == nil, let path = env["DOCCONV_TEST_SNAPSHOT"] else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            snapshot(to: URL(fileURLWithPath: path))
            NSApp.terminate(nil)
        }
    }

    static func snapshot(to url: URL) {
        guard let window = NSApp.windows.first(where: { $0.isVisible }) else { return }
        snapshot(window: window, to: url)
    }

    static func snapshot(window: NSWindow, to url: URL) {
        guard let view = window.contentView?.superview ?? window.contentView else { return }
        guard let layer = view.layer else {
            // Không có layer: dùng cacheDisplay (không vẽ được chữ trên một số control).
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
            return
        }
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
