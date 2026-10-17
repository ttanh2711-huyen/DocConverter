import Foundation

/// Tìm trình thông dịch Python có cài `docconv`.
public enum PythonLocator {
    /// Môi trường do app quản lý (tạo ở lần chạy đầu). `DOCCONV_APP_SUPPORT` để thử nghiệm ở thư mục khác.
    public static var managedEnvironment: URL {
        let support = ProcessInfo.processInfo.environment["DOCCONV_APP_SUPPORT"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("DocConverter", isDirectory: true)
        return support.appendingPathComponent("venv", isDirectory: true)
    }

    /// Python chỉ định sẵn, bỏ qua môi trường được quản lý: biến môi trường `DOCCONV_PYTHON`, hoặc venv của `core/`
    /// khi phát triển (Info.plist, khoá `DocConverterDevPython`, do `scripts/make-app.sh --dev` ghi).
    public static func override(bundle: Bundle = .main,
                                environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        var candidates: [String] = []
        if let env = environment["DOCCONV_PYTHON"] { candidates.append(env) }
        if let dev = bundle.object(forInfoDictionaryKey: "DocConverterDevPython") as? String { candidates.append(dev) }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }.map { URL(fileURLWithPath: $0) }
    }
}
