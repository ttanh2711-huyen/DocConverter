import AppKit
import DocConverterKit
import SwiftUI

/// Tuỳ chọn đầu ra: định dạng cho PDF và nơi lưu.
struct OutputOptionsView: View {
    typealias Keys = ConversionOptions.Keys
    @AppStorage(Keys.pdfFormat) private var pdfFormat = ConversionOptions.PDFFormat.markdown.rawValue
    @AppStorage(Keys.useOutputFolder) private var useOutputFolder = false
    @AppStorage(Keys.outputFolder) private var outputFolder = ""

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
