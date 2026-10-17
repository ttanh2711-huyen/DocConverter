import AppKit
import DocConverterKit
import SwiftUI

/// Tuỳ chọn đầu ra: định dạng cho PDF và nơi lưu.
struct OutputOptionsView: View {
    typealias Keys = ConversionOptions.Keys
    @AppStorage(Keys.pdfFormat) private var pdfFormat = ConversionOptions.PDFFormat.markdown.rawValue
    @AppStorage(Keys.useOutputFolder) private var useOutputFolder = false
    @AppStorage(Keys.outputFolder) private var outputFolder = ""
    @AppStorage(Keys.trashOriginals) private var trashOriginals = false
    @AppStorage(Keys.trashOriginalsConfirmed) private var trashOriginalsConfirmed = false
    @State private var confirmTrash = false

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                Text("Định dạng cho PDF:").gridColumnAlignment(.trailing)
                Picker("Định dạng cho PDF", selection: $pdfFormat) {
                    ForEach(ConversionOptions.PDFFormat.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            GridRow {
                Text("Lưu vào:")
                HStack(spacing: 12) {
                    Picker("Lưu vào", selection: $useOutputFolder) {
                        Text("Cạnh tệp gốc").tag(false)
                        Text("Thư mục khác").tag(true)
                    }
                    .pickerStyle(.radioGroup)
                    .horizontalRadioGroupLayout()
                    .labelsHidden()
                    .fixedSize()
                    if useOutputFolder {
                        Button(outputFolder.isEmpty ? "Chọn thư mục…" : "Đổi…") { pickFolder() }
                        if !outputFolder.isEmpty {
                            Label(displayPath, systemImage: "folder")
                                .lineLimit(1).truncationMode(.head)
                                .foregroundStyle(.secondary)
                                .help(outputFolder)
                        }
                    }
                }
            }
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                Toggle("Xoá tệp gốc sau khi chuyển thành công (đưa vào Thùng rác)", isOn: Binding(
                    get: { trashOriginals },
                    set: { on in
                        if on && !trashOriginalsConfirmed { confirmTrash = true } else { trashOriginals = on }
                    }))
            }
        }
        .confirmationDialog("Xoá tệp gốc sau khi chuyển đổi?", isPresented: $confirmTrash) {
            Button("Bật tuỳ chọn này", role: .destructive) {
                trashOriginalsConfirmed = true
                trashOriginals = true
            }
            Button("Không", role: .cancel) {}
        } message: {
            Text("Sau khi mọi tệp kết quả của một tệp đã được tạo thành công, tệp gốc sẽ được chuyển vào Thùng rác. "
                 + "Bạn có thể khôi phục từ Thùng rác. Tệp lỗi, bị huỷ hoặc chuyển chưa đủ sẽ được giữ nguyên.")
        }
        .onChange(of: useOutputFolder) { _, on in
            if on && outputFolder.isEmpty { pickFolder() }
        }
    }

    private var displayPath: String {
        (outputFolder as NSString).abbreviatingWithTildeInPath
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
