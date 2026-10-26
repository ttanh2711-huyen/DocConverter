import DocConverterKit
import SwiftUI

/// Thanh dưới cùng: tiến độ/thống kê (bấm để lọc), nơi lưu (đổi nhanh), mở kết quả và nút Bắt đầu/Huỷ.
struct ActionBar: View {
    @Bindable var model: AppModel
    @AppStorage(ConversionOptions.Keys.useOutputFolder) private var useOutputFolder = false
    @AppStorage(ConversionOptions.Keys.outputFolder) private var outputFolder = ""

    var body: some View {
        // Cửa sổ hẹp: rút gọn dần số đếm rồi đến các nút phụ, để không tràn.
        ViewThatFits(in: .horizontal) {
            bar(compactCounts: false, compactButtons: false)
            bar(compactCounts: true, compactButtons: false)
            bar(compactCounts: true, compactButtons: true)
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func bar(compactCounts: Bool, compactButtons: Bool) -> some View {
        let s = model.store.summary
        let start = model.startCount
        return HStack(spacing: 12) {
            if model.store.isRunning {
                progress(s)
            } else if s.total > 0 {
                counts(s, compact: compactCounts)
            } else {
                Label("Thêm tệp để bắt đầu", systemImage: "info.circle").foregroundStyle(.secondary)
                    .fixedSize()
            }

            Spacer(minLength: 8)

            destinationMenu(compact: compactButtons)

            // Xong hết: "Xem kết quả" thành nút chính; còn tệp cần chạy: nút phụ bên cạnh "Chuyển đổi".
            if !model.store.isRunning, !model.allOutputs.isEmpty {
                Button { model.revealAllOutputs() } label: {
                    Label("Xem kết quả", systemImage: "folder")
                        .labelStyle(compactButtons && start.count > 0 ? AnyLabelStyle(.iconOnly) : AnyLabelStyle(.titleAndIcon))
                        .frame(minWidth: start.count == 0 ? 110 : nil)
                }
                .buttonStyle(start.count == 0 ? AnyPrimitiveButtonStyle(.borderedProminent) : AnyPrimitiveButtonStyle(.bordered))
                .controlSize(.large)
                .help("Hiện tất cả tệp kết quả trong Finder (⇧⌘R)")
            }

            if model.store.isRunning {
                Button(role: .cancel) { model.cancel() } label: {
                    Label("Huỷ", systemImage: "stop.fill").frame(minWidth: 96)
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                .help("Dừng ngay, không để lại tệp dở dang (⌘. hoặc Esc)")
            } else if start.count > 0 || model.allOutputs.isEmpty {
                Button { model.start() } label: {
                    Label(start.isRetry ? "Thử lại \(start.count) tệp" : startTitle(start.count),
                          systemImage: start.isRetry ? "arrow.clockwise" : "play.fill")
                        .frame(minWidth: 96)
                        .monospacedDigit()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canStart)
                .help("Bắt đầu chuyển đổi (⌘R hoặc ↩)")
            }
        }
    }

    private func counts(_ s: JobStore.Summary, compact: Bool) -> some View {
        HStack(spacing: compact ? 0 : 4) {
            Count(value: s.done, label: "hoàn tất", color: .green, compact: compact) { model.filter = .done }
            Count(value: s.failed + s.cancelled, label: "lỗi", color: .red, compact: compact) { model.filter = .issues }
            Count(value: s.skipped, label: "bỏ qua", color: .secondary, compact: compact) { model.filter = .issues }
            Count(value: s.active, label: "đang chờ", color: .accentColor, compact: compact) { model.filter = .active }
            if let book = model.store.register {
                RegisterChip(result: book, compact: compact) { model.openRegister() }
            }
        }
        .fixedSize()
    }

    private func startTitle(_ count: Int) -> String {
        count == 0 ? "Bắt đầu" : "Chuyển đổi \(count) tệp"
    }

    private func progress(_ s: JobStore.Summary) -> some View {
        let finished = s.done + s.failed + s.cancelled
        let current = model.store.items.first(where: \.isRunning)?.url.lastPathComponent
        return HStack(spacing: 10) {
            ProgressView(value: model.store.progress)
                .frame(width: 140)
            VStack(alignment: .leading, spacing: 0) {
                Text("Đang xử lý \(min(finished + 1, s.total - s.skipped))/\(s.total - s.skipped)")
                    .fontWeight(.medium).monospacedDigit()
                if let current {
                    Text(current).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
        }
    }

    /// Nơi lưu: hiện ngay trên thanh, đổi bằng một lần chọn mà không cần mở bảng tuỳ chọn.
    private func destinationMenu(compact: Bool) -> some View {
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
                .labelStyle(compact ? AnyLabelStyle(.iconOnly) : AnyLabelStyle(.titleAndIcon))
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .fixedSize()
        .foregroundStyle(.secondary)
        .disabled(model.store.isRunning)
        .help(useOutputFolder ? "Lưu vào \(outputFolder)" : "Kết quả được lưu cạnh tệp gốc. Bấm để đổi.")
    }

    private var destination: String {
        guard useOutputFolder, !outputFolder.isEmpty else { return "Lưu cạnh tệp gốc" }
        // Chỉ tên thư mục cho gọn; đường dẫn đầy đủ nằm trong chú thích và trong menu.
        let name = (outputFolder as NSString).lastPathComponent
        return "Lưu vào “\(name.count > 24 ? name.prefix(23) + "…" : name)”"
    }
}

/// Số đếm có chấm màu; bấm để lọc danh sách.
private struct Count: View {
    let value: Int
    let label: String
    let color: Color
    var compact = false
    let action: () -> Void

    var body: some View {
        if value > 0 {
            Button(action: action) {
                HStack(spacing: 5) {
                    Circle().fill(color).frame(width: 7, height: 7)
                    Text(compact ? "\(value)" : "\(value) \(label)").monospacedDigit()
                }
                .padding(.horizontal, 7).padding(.vertical, 3)
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("\(value) \(label) — bấm để chỉ hiện các tệp này")
        }
    }
}

/// Cho phép chọn kiểu nhãn theo điều kiện.
private struct AnyLabelStyle: LabelStyle {
    private let make: (Configuration) -> AnyView

    init<S: LabelStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

/// Cho phép chọn kiểu nút theo điều kiện.
private struct AnyPrimitiveButtonStyle: PrimitiveButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: PrimitiveButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

/// Kết quả ghi sổ tổng hợp; bấm để mở sổ.
private struct RegisterChip: View {
    let result: RegisterResult
    let compact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: result.error == nil ? "tablecells.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(result.error == nil ? .green : .orange)
                Text(compact ? "\(result.added + result.updated)" : label).monospacedDigit()
            }
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color.green.opacity(result.error == nil ? 0.12 : 0), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(result.error ?? "Sổ \(result.url.lastPathComponent): \(result.total) văn bản. Bấm để mở (⇧⌘E).")
    }

    private var label: String {
        if result.error != nil { return "Chưa ghi được sổ" }
        let count = result.added + result.updated
        return count == 0 ? "Sổ: không có văn bản mới" : "\(count) văn bản vào sổ"
    }
}
