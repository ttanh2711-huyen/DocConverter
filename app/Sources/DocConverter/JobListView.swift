import AppKit
import DocConverterKit
import SwiftUI

struct JobListView: View {
    @Bindable var model: AppModel

    var body: some View {
        List(selection: $model.selection) {
            ForEach(model.store.items) { item in
                JobRow(item: item).tag(item.id)
            }
        }
        .listStyle(.inset)
        .onDeleteCommand { model.removeSelected() }
        .contextMenu(forSelectionType: JobItem.ID.self) { ids in
            let items = model.store.items.filter { ids.contains($0.id) }
            let targets = items.flatMap(\.revealTargets)
            Button("Hiện kết quả trong Finder") { NSWorkspace.shared.activateFileViewerSelecting(targets) }
                .disabled(targets.isEmpty)
            Button("Hiện tệp gốc trong Finder") {
                NSWorkspace.shared.activateFileViewerSelecting(items.filter { !$0.sourceTrashed }.map(\.url))
            }
            Divider()
            Button("Xoá khỏi danh sách") { model.store.remove(ids); model.selection.subtract(ids) }
                .disabled(model.store.isRunning)
        } primaryAction: { ids in
            let targets = model.store.items.filter { ids.contains($0.id) }.flatMap(\.revealTargets)
            if !targets.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(targets) }
        }
    }
}

struct JobRow: View {
    let item: JobItem
    @State private var showDetail = false
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 30, height: 30)
                .opacity(item.status == .pending || item.status == .done || item.isRunning ? 1 : 0.55)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.url.lastPathComponent)
                    .fontWeight(.medium)
                    .lineLimit(1).truncationMode(.middle)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(subtitleStyle)
                    .lineLimit(1).truncationMode(.middle)
                    .help(item.status == .pending ? (item.url.path as NSString).abbreviatingWithTildeInPath : subtitle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            actions
            StatusBadge(status: item.status)
                .frame(width: 92, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .contentShape(.rect)
        .onHover { hovering = $0 }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: 6) {
            if item.detail != nil {
                Button("Chi tiết lỗi", systemImage: "info.circle") { showDetail = true }
                    .help("Xem chi tiết lỗi")
                    .popover(isPresented: $showDetail, arrowEdge: .bottom) { ErrorDetail(item: item) }
            }
            if !item.revealTargets.isEmpty {
                Button("Hiện trong Finder", systemImage: "magnifyingglass") {
                    NSWorkspace.shared.activateFileViewerSelecting(item.revealTargets)
                }
                .help("Hiện tệp kết quả trong Finder")
                .opacity(hovering ? 1 : 0.45)
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .imageScale(.large)
    }

    /// Dòng phụ: thư mục chứa khi chờ; bước đang làm; kết quả; hoặc lý do lỗi/bỏ qua.
    private var subtitle: String {
        switch item.status {
        case .pending: return location
        case .running(let message): return message
        case .done:
            let kinds = item.revealTargets.map { "." + $0.pathExtension }
            var parts = ["Đã tạo " + (kinds.isEmpty ? "kết quả" : kinds.joined(separator: ", "))]
            if item.sourceTrashed { parts.append("tệp gốc đã vào Thùng rác") }
            if let note = item.note { parts.append(note) }
            return parts.joined(separator: " · ")
        case .failed(let message), .skipped(let message): return message
        case .cancelled: return location
        }
    }

    private var subtitleStyle: AnyShapeStyle {
        if case .failed = item.status { return AnyShapeStyle(.red) }
        return AnyShapeStyle(.secondary)
    }

    /// Thư mục chứa tệp, tính từ thư mục gốc đã chọn (đường dẫn đầy đủ nằm trong tooltip).
    private var location: String {
        let parent = item.url.deletingLastPathComponent().path
        if parent != item.base.path, parent.hasPrefix(item.base.path + "/") {
            return item.base.lastPathComponent + "/" + String(parent.dropFirst(item.base.path.count + 1))
        }
        return item.url.deletingLastPathComponent().lastPathComponent
    }
}

private extension JobItem {
    var isRunning: Bool { if case .running = status { true } else { false } }
}

struct StatusBadge: View {
    let status: JobItem.Status

    var body: some View {
        HStack(spacing: 5) {
            if case .running = status {
                ProgressView().controlSize(.mini)
            }
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(color.opacity(0.14), in: .capsule)
    }

    private var title: String {
        switch status {
        case .pending: "Đang chờ"
        case .running: "Đang xử lý"
        case .done: "Hoàn tất"
        case .failed: "Lỗi"
        case .skipped: "Bỏ qua"
        case .cancelled: "Đã huỷ"
        }
    }

    private var color: Color {
        switch status {
        case .pending, .skipped: .secondary
        case .running: .blue
        case .done: .green
        case .failed: .red
        case .cancelled: .orange
        }
    }
}

private struct ErrorDetail: View {
    let item: JobItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(item.url.lastPathComponent, systemImage: "exclamationmark.triangle.fill")
                .font(.headline).foregroundStyle(.red)
            ScrollView {
                Text(item.detail ?? "")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button("Sao chép") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.detail ?? "", forType: .string)
                }
            }
        }
        .padding(14)
        .frame(width: 480, height: 260)
    }
}
