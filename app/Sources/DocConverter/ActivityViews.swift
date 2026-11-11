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
        let recorded = model.store.items.filter(\.registered).count
        if recorded > 0 { parts.append("\(recorded) vào sổ") }
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
            .buttonStyle(ProminentActionStyle(tint: Theme.failed))
            .keyboardShortcut(.cancelAction)
            .help("Dừng ngay, không để lại tệp dở dang (⌘. hoặc Esc)")
        } else if start.count == 0, !model.allOutputs.isEmpty {
            Button { model.revealAllOutputs() } label: {
                Label("Xem kết quả", systemImage: "folder")
            }
            .buttonStyle(ProminentActionStyle(tint: Theme.done))
            .help("Hiện tất cả tệp kết quả trong Finder (⇧⌘R)")
        } else {
            Button { model.start() } label: {
                Label(start.isRetry ? "Thử lại \(start.count) tệp" : (start.count == 0 ? "Chuyển đổi" : "Chuyển đổi \(start.count) tệp"),
                      systemImage: start.isRetry ? "arrow.clockwise" : "play.fill")
                    .monospacedDigit()
                    .symbolEffect(.bounce, value: start.count)
            }
            .buttonStyle(ProminentActionStyle())
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

/// Kết quả tổng hợp ở đầu danh sách: bấm để mở tệp tổng hợp của lần này (không có thì mở sổ chung);
/// mũi tên bên cạnh liệt kê cả hai loại.
struct RegisterMenu: View {
    let model: AppModel

    var body: some View {
        let batches = model.store.batchRegisters
        let shared = model.store.register
        let failed = (batches + [shared].compactMap { $0 }).first { $0.error != nil }
        let count = model.store.items.filter(\.registered).count
        HStack(spacing: 2) {
            Button {
                if batches.contains(where: { $0.error == nil }) { model.openBatchRegister() } else { model.openRegister() }
            } label: {
                ViewThatFits(in: .horizontal) {
                    chip(failed != nil && count == 0 ? "Chưa ghi được tệp tổng hợp" : "\(count) văn bản đã tổng hợp",
                         failed: failed != nil && count == 0)
                    chip(failed != nil && count == 0 ? "!" : "\(count)", failed: failed != nil && count == 0)
                }
            }
            .buttonStyle(.plain)
            .help(failed?.error ?? "Mở tệp tổng hợp vừa tạo")

            Menu {
                ForEach(batches, id: \.url) { book in
                    if let error = book.error {
                        Text(error)
                    } else {
                        Button("Mở “\(book.url.deletingPathExtension().lastPathComponent)”", systemImage: "tablecells") {
                            NSWorkspace.shared.open(book.url)
                        }
                    }
                }
                if batches.contains(where: { $0.error == nil }) {
                    Button("Hiện tệp tổng hợp lần này trong Finder", systemImage: "folder") {
                        NSWorkspace.shared.activateFileViewerSelecting(batches.filter { $0.error == nil }.map(\.url))
                    }
                }
                if let shared {
                    Divider()
                    if let error = shared.error {
                        Text(error)
                    } else {
                        Button("Mở sổ chung (\(shared.total) văn bản)", systemImage: "books.vertical") { model.openRegister() }
                    }
                }
            } label: {
                Image(systemName: "chevron.down")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Tệp tổng hợp lần này và sổ chung")
        }
        .accessibilityElement(children: .contain)
    }

    private func chip(_ text: String, failed: Bool) -> some View {
        let color = failed ? Theme.failed : Theme.seal
        return HStack(spacing: 5) {
            Image(systemName: failed ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
            Text(text).monospacedDigit().lineLimit(1)
            Image(systemName: "arrow.up.forward").font(.caption2.weight(.semibold))
        }
        .fixedSize()
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(color.opacity(0.1), in: .capsule)
        .contentShape(.capsule)
    }
}

/// Kiểu nút hành động chính: nền màu nhấn đậm dạng viên thuốc, chữ trắng đậm, bóng nhẹ cùng màu,
/// nổi hẳn so với các nút biểu tượng khác trên thanh công cụ. Vẫn theo màu nhấn người dùng chọn.
struct ProminentActionStyle: ButtonStyle {
    var tint: Color = .accentColor
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlActiveState) private var activeState
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        let active = activeState != .inactive
        configuration.label
            .font(.system(size: 13, weight: .bold))  // chữ đậm: đạt 3:1 trên nền màu nhấn xanh mặc định (4:1)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(isEnabled ? .white : .secondary)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background {
                Capsule()
                    .fill(isEnabled ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(.quaternary))
                    .brightness(configuration.isPressed ? -0.08 : (hovering ? 0.05 : 0))
                    .opacity(isEnabled && !active ? 0.75 : 1)
            }
            .overlay { Capsule().strokeBorder(.white.opacity(isEnabled ? 0.18 : 0), lineWidth: 0.5) }
            .shadow(color: isEnabled && active ? tint.opacity(0.35) : .clear, radius: 5, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(.capsule)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
