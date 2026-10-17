import DocConverterKit
import SwiftUI

/// Cửa sổ Cài đặt: nhận dạng chữ (OCR) và bảng cho PDF.
struct SettingsView: View {
    typealias Keys = ConversionOptions.Keys
    typealias OCR = ConversionOptions.OCR
    @AppStorage(Keys.ocrMode) private var mode = OCR.Mode.auto.rawValue
    @AppStorage(Keys.ocrEngine) private var engine = OCR.Engine.ocrmac.rawValue
    @AppStorage(Keys.ocrTables) private var tables = true

    var body: some View {
        Form {
            Section {
                Picker("Nhận dạng chữ (OCR):", selection: $mode) {
                    ForEach(OCR.Mode.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Công cụ OCR:", selection: $engine) {
                    ForEach(OCR.Engine.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                .disabled(mode == OCR.Mode.off.rawValue)
                Toggle("Nhận dạng cấu trúc bảng", isOn: $tables)
            } footer: {
                Text("Ngôn ngữ nhận dạng: tiếng Việt và tiếng Anh. Chọn \"Luôn nhận dạng\" khi PDF có lớp chữ bị lỗi phông. "
                     + "Tắt nhận dạng bảng giúp chạy nhanh hơn nhưng bảng sẽ không được tách thành từng ô.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }
}
