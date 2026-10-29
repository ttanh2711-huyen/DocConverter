import DocConverterKit
import SwiftUI

/// Ô trạng thái giữa thanh công cụ (kiểu Xcode): việc cần làm tiếp, tiến độ khi chạy, tóm tắt khi xong.
/// Nằm trên cùng cửa sổ thay cho thanh dưới đáy, để tiến độ luôn nhìn thấy.
struct ActivityPill: View {
    let model: AppModel

    var body: some View {
        let s = model.store.summary
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                icon(s)
                Text(title(s))
                    .fontWeight(.medium)
                    .lineLimit(1).truncationMode(.middle)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .font(.callout)
            if model.store.isRunning {
                ProgressView(value: model.store.progress)
                    .progressViewStyle(.linear)
                    .controlSize(.mini)
                    .tint(Theme.running)
                    .animation(.easeOut(duration: 0.3), value: model.store.progress)
            }
        }
        .padding(.horizontal, 12)
        .frame(minWidth: 220, idealWidth: 340, maxWidth: 420, minHeight: 28)
        .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 7))
        .accessibilityElement(children: .combine)
        .help(model.store.isRunning ? "Tiến độ chuyển đổi" : "Trạng thái danh sách")
    }

    @ViewBuilder private func icon(_ s: JobStore.Summary) -> some View {
        if model.store.isRunning {
            ProgressView().controlSize(.small)
        } else if s.total == 0 {
            Image(systemName: "tray.and.arrow.down").foregroundStyle(.secondary)
        } else if s.active > 0 {
            Image(systemName: "doc.on.doc").foregroundStyle(.secondary)
        } else {
            let failed = s.failed + s.cancelled > 0
            Image(systemName: failed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(failed ? Theme.failed : Theme.done)
                .symbolEffect(.bounce, value: s.done)
        }
    }

    private func title(_ s: JobStore.Summary) -> String {
        if model.store.isRunning {
            let finished = s.done + s.failed + s.cancelled
            let current = model.store.items.first(where: \.isRunning)?.url.lastPathComponent ?? ""
            return "Đang chuyển \(min(finished + 1, s.total - s.skipped))/\(s.total - s.skipped) · \(current)"
        }
        if s.total == 0 { return "Kéo thả tệp vào cửa sổ để bắt đầu" }
        if s.active > 0 { return "\(s.active) tệp sẵn sàng chuyển đổi" }
        var parts = ["\(s.done) hoàn tất"]
        if s.failed + s.cancelled > 0 { parts.append("\(s.failed + s.cancelled) lỗi") }
        if let book = model.store.register, book.error == nil, book.added + book.updated > 0 {
            parts.append("\(book.added + book.updated) vào sổ")
        }
        return parts.joined(separator: " · ")
    }
}

/// Nút chính bên phải thanh công cụ, đổi theo ngữ cảnh: Chuyển đổi → Huỷ → Thử lại → Xem kết quả.
struct PrimaryActionButton: View {
    let model: AppModel

    var body: some View {
        let start = model.startCount
        if model.store.isRunning {
            Button(role: .cancel) { model.cancel() } label: {
                Label("Huỷ", systemImage: "stop.fill")
            }
            .labelStyle(.titleAndIcon)
            .keyboardShortcut(.cancelAction)
            .help("Dừng ngay, không để lại tệp dở dang (⌘. hoặc Esc)")
        } else if start.count == 0, !model.allOutputs.isEmpty {
            Button { model.revealAllOutputs() } label: {
                Label("Xem kết quả", systemImage: "folder")
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.borderedProminent)
            .help("Hiện tất cả tệp kết quả trong Finder (⇧⌘R)")
        } else {
            Button { model.start() } label: {
                Label(start.isRetry ? "Thử lại \(start.count) tệp" : (start.count == 0 ? "Chuyển đổi" : "Chuyển đổi \(start.count) tệp"),
                      systemImage: start.isRetry ? "arrow.clockwise" : "play.fill")
                    .monospacedDigit()
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canStart)
            .help("Bắt đầu chuyển đổi (⌘R hoặc ↩)")
        }
    }
}

/// Nơi lưu kết quả, đổi bằng một lần chọn trên thanh công cụ.
struct DestinationMenu: View {
    let model: AppModel
    @AppStorage(ConversionOptions.Keys.useOutputFolder) private var useOutputFolder = false
    @AppStorage(ConversionOptions.Keys.outputFolder) private var outputFolder = ""

    var body: some View {
        Menu {
            Picker("Nơi lưu", selection: Binding(
                get: { useOutputFolder && !outputFolder.isEmpty },
                set: { folder in
                    if folder { if outputFolder.isEmpty { model.chooseOutputFolder() } else { useOutputFolder = true } }
                    else { useOutputFolder = false }
                })) {
                Label("Cạnh tệp gốc", systemImage: "arrow.turn.down.right").tag(false)
                if !outputFolder.isEmpty {
                    Label((outputFolder as NSString).abbreviatingWithTildeInPath, systemImage: "folder").tag(true)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button("Chọn thư mục khác…", systemImage: "folder.badge.plus") { model.chooseOutputFolder() }
            if useOutputFolder, !outputFolder.isEmpty {
                Button("Mở thư mục lưu", systemImage: "arrow.up.forward.app") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: outputFolder))
                }
            }
        } label: {
            Label(destination, systemImage: useOutputFolder ? "folder.fill" : "arrow.turn.down.right")
        }
        .disabled(model.store.isRunning)
        .help(useOutputFolder ? "Lưu vào \(outputFolder)" : "Kết quả được lưu cạnh tệp gốc. Bấm để đổi.")
    }

    private var destination: String {
        guard useOutputFolder, !outputFolder.isEmpty else { return "Lưu cạnh tệp gốc" }
        return "Lưu vào “\((outputFolder as NSString).lastPathComponent)”"
    }
}

/// Kết quả ghi sổ tổng hợp ở đầu danh sách; bấm để mở sổ.
struct RegisterChip: View {
    let result: RegisterResult
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Thiếu chỗ thì chỉ còn biểu tượng và con số.
            ViewThatFits(in: .horizontal) {
                content(label)
                content(result.error != nil ? "!" : "\(result.added + result.updated)")
            }
            .foregroundStyle(result.error == nil ? Theme.seal : Theme.failed)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background((result.error == nil ? Theme.seal : Theme.failed).opacity(0.1), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(result.error ?? "Sổ \(result.url.lastPathComponent): \(result.total) văn bản. Bấm để mở (⇧⌘E).")
    }

    private func content(_ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: result.error == nil ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            Text(text).monospacedDigit().lineLimit(1)
            Image(systemName: "arrow.up.forward").font(.caption2.weight(.semibold))
        }
        .fixedSize()
    }

    private var label: String {
        if result.error != nil { return "Chưa ghi được sổ" }
        let count = result.added + result.updated
        return count == 0 ? "Không có văn bản mới vào sổ" : "\(count) văn bản vào sổ"
    }
}
