import Foundation

/// Tìm trình thông dịch Python có cài `docconv`.
public enum PythonLocator {
    /// Môi trường do app quản lý (tạo ở lần chạy đầu).
    public static var managedEnvironment: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DocConverter/venv", isDirectory: true)
    }

    /// Thứ tự: biến môi trường `DOCCONV_PYTHON` → môi trường được quản lý → venv của `core/` khi phát triển
    /// (đường dẫn ghi vào Info.plist, khoá `DocConverterDevPython`, bởi `scripts/make-app.sh --dev`).
    public static func resolve(bundle: Bundle = .main, environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        var candidates: [String] = []
        if let env = environment["DOCCONV_PYTHON"] { candidates.append(env) }
        candidates.append(managedEnvironment.appendingPathComponent("bin/python").path)
        if let dev = bundle.object(forInfoDictionaryKey: "DocConverterDevPython") as? String { candidates.append(dev) }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }.map { URL(fileURLWithPath: $0) }
    }
}
