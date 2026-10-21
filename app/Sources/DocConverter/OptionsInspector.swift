import DocConverterKit
import SwiftUI

/// Bảng tuỳ chọn bên phải, xếp theo thứ tự thao tác: kết quả → nơi lưu → tệp gốc → OCR.
/// Gọn để vừa một màn hình, không phải cuộn; giải thích dài nằm trong chú thích khi rê chuột.
struct OptionsInspector: View {
    typealias Keys = ConversionOptions.Keys
    typealias OCR = ConversionOptions.OCR
    let model: AppModel
    @AppStorage("includeSubfolders") private var includeSubfolders = true
    @AppStorage(Keys.pdfFormat) private var pdfFormat = ConversionOptions.PDFFormat.markdown.rawValue
    @AppStorage(Keys.useOutputFolder) private var useOutputFolder = false
    @AppStorage(Keys.outputFolder) private var outputFolder = ""
    @AppStorage(Keys.trashOriginals) private var trashOriginals = false
    @AppStorage(Keys.trashOriginalsConfirmed) private var trashOriginalsConfirmed = false
    @AppStorage(Keys.ocrMode) private var ocrMode = OCR.Mode.auto.rawValue
    @AppStorage(Keys.ocrEngine) private var ocrEngine = OCR.Engine.ocrmac.rawValue
    @AppStorage(Keys.ocrTables) private var ocrTables = true
    @State private var confirmTrash = false

    var body: some View {
        Form {
            Section {
                Picker("PDF thành", selection: $pdfFormat) {
                    Text("Markdown").tag(ConversionOptions.PDFFormat.markdown.rawValue)
                    Text("Word").tag(ConversionOptions.PDFFormat.word.rawValue)
                    Text("Cả hai").tag(ConversionOptions.PDFFormat.both.rawValue)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help("Word, Excel, PowerPoint, HTML, CSV… luôn được chuyển sang Markdown.")
            } header: {
                SectionHeader("Chuyển PDF thành", systemImage: "doc.richtext")
            } footer: {
                Footnote("Tệp Office, HTML, CSV… luôn ra Markdown.")
            }

            Section {
                Picker("Lưu", selection: Binding(
                    get: { useOutputFolder },
                    set: { on in
                        if on && outputFolder.isEmpty { model.chooseOutputFolder() } else { useOutputFolder = on }
                    })) {
                    Text("Cạnh tệp gốc").tag(false)
                    Text("Thư mục khác").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if useOutputFolder {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill").foregroundStyle(.tint)
                        Text(outputFolder.isEmpty ? "Chưa chọn" : (outputFolder as NSString).abbreviatingWithTildeInPath)
                            .lineLimit(1).truncationMode(.head)
                            .foregroundStyle(outputFolder.isEmpty ? .secondary : .primary)
                            .help("\(outputFolder)\nGiữ nguyên cấu trúc thư mục con của thư mục đầu vào.")
                        Spacer(minLength: 4)
                        Button("Đổi…") { model.chooseOutputFolder() }
                            .controlSize(.small)
                    }
                }
            } header: {
                SectionHeader("Nơi lưu kết quả", systemImage: "externaldrive")
            }

            Section {
                Toggle("Gồm cả thư mục con", isOn: $includeSubfolders)
                    .help("Áp dụng khi thêm thư mục.")
                Toggle("Đưa tệp gốc vào Thùng rác", isOn: Binding(
                    get: { trashOriginals },
                    set: { on in
                        if on && !trashOriginalsConfirmed { confirmTrash = true } else { trashOriginals = on }
                    }))
                    .help("Chỉ khi mọi kết quả đã tạo xong. Tệp lỗi hoặc bị huỷ luôn được giữ nguyên.")
            } header: {
                SectionHeader("Tệp gốc", systemImage: "folder.badge.gearshape")
            }

            Section {
                Picker("OCR", selection: $ocrMode) {
                    Text("Tự động").tag(OCR.Mode.auto.rawValue)
                    Text("Luôn").tag(OCR.Mode.force.rawValue)
                    Text("Tắt").tag(OCR.Mode.off.rawValue)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help("Tự động: chỉ nhận dạng trang không có chữ (bản scan). "
                      + "Luôn: dùng khi PDF có lớp chữ bị lỗi phông.")
                Picker("Công cụ", selection: $ocrEngine) {
                    Text("Apple Vision").tag(OCR.Engine.ocrmac.rawValue)
                    Text("EasyOCR").tag(OCR.Engine.easyocr.rawValue)
                }
                .disabled(ocrMode == OCR.Mode.off.rawValue)
                Toggle("Nhận dạng bảng", isOn: $ocrTables)
                    .help("Tắt giúp chạy nhanh hơn nhưng bảng sẽ không được tách thành từng ô.")
            } header: {
                SectionHeader("Nhận dạng chữ (PDF scan)", systemImage: "text.viewfinder")
            } footer: {
                Footnote("Tiếng Việt và tiếng Anh.")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Đưa tệp gốc vào Thùng rác sau khi chuyển?", isPresented: $confirmTrash) {
            Button("Bật tuỳ chọn này", role: .destructive) {
                trashOriginalsConfirmed = true
                trashOriginals = true
            }
            Button("Không", role: .cancel) {}
        } message: {
            Text("Tệp gốc chỉ được chuyển vào Thùng rác khi mọi tệp kết quả đã được tạo thành công, "
                 + "và có thể khôi phục từ Thùng rác. Tệp lỗi, bị huỷ hoặc chuyển chưa đủ sẽ được giữ nguyên.")
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
    }
}

private struct Footnote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption).foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
