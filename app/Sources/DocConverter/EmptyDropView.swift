import SwiftUI

/// Màn hình khi chưa có tệp: vùng thả lớn và hai cách thêm tệp.
struct EmptyDropView: View {
    let model: AppModel
    let targeted: Bool

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: targeted ? "arrow.down.doc.fill" : "arrow.down.doc")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(targeted ? Color.accentColor : .secondary)
                .contentTransition(.symbolEffect(.replace))

            VStack(spacing: 6) {
                Text("Kéo thả tệp hoặc thư mục vào đây")
                    .font(.title3.weight(.semibold))
                Text("hoặc chọn từ máy")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button { model.chooseFiles() } label: {
                    Label("Chọn tệp…", systemImage: "doc").frame(minWidth: 110)
                }
                .buttonStyle(.borderedProminent)
                Button { model.chooseFolders() } label: {
                    Label("Chọn thư mục…", systemImage: "folder").frame(minWidth: 110)
                }
            }
            .controlSize(.large)

            VStack(spacing: 8) {
                FormatLine(inputs: ["PDF"], outputs: ["MD", "DOCX"])
                FormatLine(inputs: ["DOCX", "XLSX", "PPTX", "HTML", "CSV", "EPUB", "…"], outputs: ["MD"])
            }
            .padding(.top, 6)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(targeted ? Color.accentColor : Color.secondary.opacity(0.35),
                              style: StrokeStyle(lineWidth: targeted ? 2 : 1.2, dash: [7, 5]))
                .background(targeted ? Color.accentColor.opacity(0.06) : .clear, in: .rect(cornerRadius: 16))
                .padding(20)
        }
        .animation(.easeOut(duration: 0.15), value: targeted)
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
