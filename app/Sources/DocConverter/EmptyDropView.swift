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

            Text(targeted ? "Thả để thêm vào danh sách" : "Kéo thả tệp hoặc thư mục vào đây")
                .font(.title2.weight(.semibold))

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

            // Ba bước của app, cũng là lời giới thiệu: thả tệp → chuyển đổi → vào sổ.
            HStack(alignment: .top, spacing: 0) {
                FlowStep(symbol: "tray.and.arrow.down.fill", color: .accentColor, title: "Thả tệp",
                         detail: "PDF, Word, Excel, PowerPoint, HTML, CSV…")
                FlowArrow()
                FlowStep(symbol: "doc.richtext.fill", color: Theme.running, title: "Chuyển đổi",
                         detail: "PDF → Markdown, Word\nTệp khác → Markdown")
                FlowArrow()
                FlowStep(symbol: "checkmark.seal.fill", color: Theme.seal, title: "Vào sổ",
                         detail: "Loại, số ký hiệu, ngày,\ncơ quan, người ký → Excel")
            }
            .padding(.top, 8)
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

private struct FlowStep: View {
    let symbol: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.13), in: .circle)
            Text(title).font(.callout.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 150)
        .accessibilityElement(children: .combine)
    }
}

private struct FlowArrow: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.tertiary)
            .frame(height: 40)
            .accessibilityHidden(true)
    }
}
