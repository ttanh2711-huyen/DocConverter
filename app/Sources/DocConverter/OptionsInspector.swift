import AppKit
import DocConverterKit
import SwiftUI

/// Bảng tuỳ chọn bên phải, xếp theo thứ tự thao tác: đầu vào → định dạng → nơi lưu → sau khi chuyển → OCR.
struct OptionsInspector: View {
    typealias Keys = ConversionOptions.Keys
    typealias OCR = ConversionOptions.OCR
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
                Picker("Định dạng", selection: $pdfFormat) {
                    Text("Markdown").tag(ConversionOptions.PDFFormat.markdown.rawValue)
                    Text("Word").tag(ConversionOptions.PDFFormat.word.rawValue)
                    Text("Cả hai").tag(ConversionOptions.PDFFormat.both.rawValue)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } header: {
                SectionHeader("Đầu ra cho PDF", systemImage: "doc.richtext")
            } footer: {
                Footnote("Word, Excel, PowerPoint, HTML… luôn được chuyển sang Markdown.")
            }

            Section {
                Picker("Nơi lưu", selection: $useOutputFolder) {
                    Text("Cạnh tệp gốc").tag(false)
                    Text("Thư mục khác").tag(true)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                if useOutputFolder {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill").foregroundStyle(.tint)
                        Text(outputFolder.isEmpty ? "Chưa chọn" : (outputFolder as NSString).abbreviatingWithTildeInPath)
                            .lineLimit(1).truncationMode(.head)
                            .foregroundStyle(outputFolder.isEmpty ? .secondary : .primary)
                            .help(outputFolder)
                        Spacer()
                        Button("Chọn…") { pickFolder() }
                    }
                }
            } header: {
                SectionHeader("Nơi lưu", systemImage: "externaldrive")
            } footer: {
                if useOutputFolder { Footnote("Giữ nguyên cấu trúc thư mục con của thư mục đầu vào.") }
            }

            Section {
                Toggle("Bao gồm thư mục con", isOn: $includeSubfolders)
                Toggle("Đưa tệp gốc vào Thùng rác", isOn: Binding(
                    get: { trashOriginals },
                    set: { on in
                        if on && !trashOriginalsConfirmed { confirmTrash = true } else { trashOriginals = on }
                    }))
            } header: {
                SectionHeader("Xử lý tệp", systemImage: "folder.badge.gearshape")
            } footer: {
                Footnote(trashOriginals
                         ? "Chỉ khi mọi kết quả đã tạo xong. Tệp lỗi hoặc bị huỷ luôn được giữ nguyên."
                         : "Áp dụng khi thêm thư mục và sau khi chuyển xong.")
            }

            Section {
                Picker("OCR", selection: $ocrMode) {
                    Text("Tự động").tag(OCR.Mode.auto.rawValue)
                    Text("Luôn nhận dạng").tag(OCR.Mode.force.rawValue)
                    Text("Tắt").tag(OCR.Mode.off.rawValue)
                }
                Picker("Công cụ", selection: $ocrEngine) {
                    Text("Apple Vision").tag(OCR.Engine.ocrmac.rawValue)
                    Text("EasyOCR").tag(OCR.Engine.easyocr.rawValue)
                }
                .disabled(ocrMode == OCR.Mode.off.rawValue)
                Toggle("Nhận dạng bảng", isOn: $ocrTables)
            } header: {
                SectionHeader("Nhận dạng chữ", systemImage: "text.viewfinder")
            } footer: {
                Footnote("Tự động: chỉ OCR trang không có chữ (bản scan). Tiếng Việt và tiếng Anh.")
            }
        }
        .formStyle(.grouped)
        .onChange(of: useOutputFolder) { _, on in
            if on && outputFolder.isEmpty { pickFolder() }
        }
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

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.title = "Chọn thư mục lưu kết quả"
        panel.prompt = "Chọn"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            outputFolder = url.path
        } else if outputFolder.isEmpty {
            useOutputFolder = false
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
