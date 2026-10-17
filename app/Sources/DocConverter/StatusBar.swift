import DocConverterKit
import SwiftUI

/// Thanh dưới cùng: thống kê, tiến độ tổng, nơi lưu và nút Bắt đầu/Huỷ.
struct StatusBar: View {
    let model: AppModel
    @AppStorage(ConversionOptions.Keys.useOutputFolder) private var useOutputFolder = false
    @AppStorage(ConversionOptions.Keys.outputFolder) private var outputFolder = ""

    var body: some View {
        let s = model.store.summary
        HStack(spacing: 14) {
            if model.store.isRunning {
                ProgressView(value: model.store.progress)
                    .frame(width: 160)
                Text("Đang xử lý \(s.done + s.failed + s.cancelled + 1)/\(s.total - s.skipped)")
                    .monospacedDigit()
            } else if s.total > 0 {
                Text("\(s.total) tệp").fontWeight(.medium)
                Count(value: s.done, label: "hoàn tất", color: .green)
                Count(value: s.failed, label: "lỗi", color: .red)
                Count(value: s.cancelled, label: "đã huỷ", color: .orange)
                Count(value: s.skipped, label: "bỏ qua", color: .secondary)
            } else {
                Text("Chưa có tệp nào").foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Label(destination, systemImage: useOutputFolder ? "folder" : "arrow.turn.down.right")
                .foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.head)
                .help(useOutputFolder ? outputFolder : "Kết quả được lưu cạnh tệp gốc")

            if model.store.isRunning {
                Button(role: .cancel) { model.cancel() } label: {
                    Label("Huỷ", systemImage: "stop.fill").frame(minWidth: 96)
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
            } else {
                Button { model.start() } label: {
                    Label("Bắt đầu", systemImage: "play.fill").frame(minWidth: 96)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canStart)
            }
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var destination: String {
        guard useOutputFolder, !outputFolder.isEmpty else { return "Lưu cạnh tệp gốc" }
        return "Lưu vào " + (outputFolder as NSString).abbreviatingWithTildeInPath
    }
}

private struct Count: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        if value > 0 {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text("\(value) \(label)").monospacedDigit()
            }
            .foregroundStyle(.secondary)
        }
    }
}
