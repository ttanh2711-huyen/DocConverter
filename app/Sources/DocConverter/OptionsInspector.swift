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
    @AppStorage(Keys.registerEnabled) private var registerEnabled = true
    @AppStorage(Keys.registerPath) private var registerPath = ""
    @State private var confirmTrash = false

    private var registerURL: URL {
        registerPath.isEmpty ? ConversionOptions.defaultRegister : URL(fileURLWithPath: registerPath)
    }

    var body: some View {
        Form {
            Section {
                InlineRow("PDF") {
                    Picker("PDF", selection: $pdfFormat) {
                        Text("Markdown").tag(ConversionOptions.PDFFormat.markdown.rawValue)
                        Text("Word").tag(ConversionOptions.PDFFormat.word.rawValue)
                        Text("Cả hai").tag(ConversionOptions.PDFFormat.both.rawValue)
                    }
                }
                .help("Định dạng tạo ra từ PDF. Word, Excel, PowerPoint, HTML, CSV… luôn được chuyển sang Markdown.")
                InlineRow("Lưu") {
                    Picker("Lưu", selection: Binding(
                        get: { useOutputFolder },
                        set: { on in
                            if on && outputFolder.isEmpty { model.chooseOutputFolder() } else { useOutputFolder = on }
                        })) {
                        Text("Cạnh tệp gốc").tag(false)
                        Text("Thư mục khác").tag(true)
                    }
                }
                if useOutputFolder {
                    FileRow(icon: "folder.fill",
                            name: outputFolder.isEmpty ? "Chưa chọn" : (outputFolder as NSString).abbreviatingWithTildeInPath,
                            help: "\(outputFolder)\nGiữ nguyên cấu trúc thư mục con của thư mục đầu vào.") {
                        Button("Đổi…") { model.chooseOutputFolder() }
                    }
                }
            } header: {
                SectionHeader("Kết quả", systemImage: "doc.richtext")
            } footer: {
                Footnote("Tệp Office, HTML, CSV… luôn ra Markdown.")
            }

            Section {
                Toggle("Ghi thông tin văn bản vào sổ", isOn: $registerEnabled)
                if registerEnabled {
                    FileRow(icon: "tablecells.fill", name: registerURL.deletingPathExtension().lastPathComponent,
                            help: registerURL.path, tint: .green) {
                        Button("Mở") { model.openRegister() }
                            .help("Mở sổ trong Excel/Numbers (⇧⌘E)")
                        Menu("Đổi") {
                            Button("Chọn sổ có sẵn…") { model.chooseRegister(existing: true) }
                            Button("Tạo sổ mới…") { model.chooseRegister(existing: false) }
                            if !registerPath.isEmpty {
                                Divider()
                                Button("Dùng sổ mặc định trong Tài liệu") { registerPath = "" }
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }
            } header: {
                SectionHeader("Sổ tổng hợp (Excel)", systemImage: "tablecells")
            } footer: {
                Footnote("Loại, số ký hiệu, ngày ban hành, cơ quan, người ký, trích yếu; cộng dồn mỗi lần chuyển.")
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
            } header: {
                SectionHeader("Nhận dạng chữ (PDF scan)", systemImage: "text.viewfinder")
            } footer: {
                HStack(spacing: 4) {
                    Footnote("Tiếng Việt và tiếng Anh.")
                    SettingsLink { Text("Công cụ, bảng…").font(.caption) }
                        .buttonStyle(.link)
                        .fixedSize()
                        .help("Chọn công cụ OCR và nhận dạng bảng trong Cài đặt (⌘,)")
                }
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

/// Nhãn ngắn bên trái và bộ chọn phân đoạn trên cùng một dòng (gọn hơn kiểu nhãn nằm trên).
private struct InlineRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title).foregroundStyle(.secondary).frame(width: 30, alignment: .leading)
            content.pickerStyle(.segmented).labelsHidden().frame(maxWidth: .infinity)
        }
    }
}

/// Dòng tệp/thư mục: biểu tượng, tên (rút gọn đầu), các nút bên phải.
private struct FileRow<Actions: View>: View {
    let icon: String
    let name: String
    let help: String
    var tint: Color = .accentColor
    @ViewBuilder let actions: Actions

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(name)
                .lineLimit(1).truncationMode(.middle)
                .help(help)
            Spacer(minLength: 4)
            actions.controlSize(.small)
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
