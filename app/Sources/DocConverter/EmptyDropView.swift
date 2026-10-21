import SwiftUI

/// Màn hình khi chưa có tệp: vùng thả lớn và hai cách thêm tệp.
struct EmptyDropView: View {
    let model: AppModel
    let targeted: Bool

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(targeted ? 0.2 : 0.1))
                    .frame(width: 88, height: 88)
                Image(systemName: targeted ? "arrow.down.doc.fill" : "arrow.down.doc")
                    .font(.system(size: 38, weight: .regular))
                    .foregroundStyle(Color.accentColor)
                    .contentTransition(.symbolEffect(.replace))
            }
            .scaleEffect(targeted ? 1.08 : 1)

            VStack(spacing: 6) {
                Text(targeted ? "Thả để thêm vào danh sách" : "Kéo thả tệp hoặc thư mục vào đây")
                    .font(.title2.weight(.semibold))
                Text("Chọn định dạng và nơi lưu ở bảng bên phải, rồi bấm Chuyển đổi.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button { model.chooseFiles() } label: {
                    Label("Chọn tệp…", systemImage: "doc").frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .help("⌘O")
                Button { model.chooseFolders() } label: {
                    Label("Chọn thư mục…", systemImage: "folder").frame(minWidth: 120)
                }
                .help("⇧⌘O")
            }
            .controlSize(.large)

            VStack(spacing: 8) {
                FormatLine(inputs: ["PDF"], outputs: ["MD", "DOCX"])
                FormatLine(inputs: ["DOCX", "XLSX", "PPTX", "HTML", "CSV", "EPUB", "…"], outputs: ["MD"])
            }
            .padding(.top, 4)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(targeted ? Color.accentColor : Color.secondary.opacity(0.3),
                              style: StrokeStyle(lineWidth: targeted ? 2 : 1.2, dash: [7, 5]))
                .background(targeted ? Color.accentColor.opacity(0.06) : Color.secondary.opacity(0.03),
                            in: .rect(cornerRadius: 18))
                .padding(16)
        }
        .animation(.spring(duration: 0.25), value: targeted)
    }
}

private struct FormatLine: View {
    let inputs: [String]
    let outputs: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(inputs, id: \.self) { Chip(text: $0) }
            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
            ForEach(outputs, id: \.self) { Chip(text: $0, accent: true) }
        }
    }
}

private struct Chip: View {
    let text: String
    var accent = false

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold).monospaced())
            .foregroundStyle(accent ? Color.accentColor : .secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background((accent ? Color.accentColor : Color.secondary).opacity(0.12), in: .rect(cornerRadius: 5))
    }
}
