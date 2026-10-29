import AppKit
import DocConverterKit
import SwiftUI

struct JobListView: View {
    @Bindable var model: AppModel

    var body: some View {
        let items = model.store.items.filter { model.filter.includes($0.status) }
        ScrollViewReader { proxy in
            List(selection: $model.selection) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    JobRow(item: item, canRemove: !model.store.isRunning,
                           stampFresh: model.stampIsFresh, stampDelay: Double(min(index, 12)) * 0.05) {
                        model.store.remove(item.id)
                        model.selection.remove(item.id)
                    }
                    .tag(item.id)
                    .id(item.id)
                }
            }
            .listStyle(.inset)
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView("Không có tệp \(model.filter.title.lowercased())",
                                           systemImage: "line.3.horizontal.decrease.circle",
                                           description: Text("Chọn \"Tất cả\" để xem toàn bộ danh sách."))
                }
            }
            // Đang chạy: tự cuộn tới tệp đang xử lý để không phải tìm.
            .onChange(of: runningID) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .onDeleteCommand { model.removeSelected() }
        .contextMenu(forSelectionType: JobItem.ID.self) { ids in
            let items = model.store.items.filter { ids.contains($0.id) }
            let targets = items.flatMap(\.revealTargets)
            Button("Mở kết quả", systemImage: "arrow.up.forward.app") { targets.forEach { NSWorkspace.shared.open($0) } }
                .disabled(targets.isEmpty)
            Button("Hiện kết quả trong Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting(targets)
            }
            .disabled(targets.isEmpty)
            Button("Hiện tệp gốc trong Finder", systemImage: "doc.viewfinder") {
                NSWorkspace.shared.activateFileViewerSelecting(items.filter { !$0.sourceTrashed }.map(\.url))
            }
            Divider()
            Button("Xoá khỏi danh sách", systemImage: "minus.circle") {
                model.store.remove(ids); model.selection.subtract(ids)
            }
            .disabled(model.store.isRunning)
        } primaryAction: { ids in
            // Bấm đúp: mở ngay tệp kết quả; chưa có kết quả thì mở tệp gốc.
            let items = model.store.items.filter { ids.contains($0.id) }
            for item in items {
                NSWorkspace.shared.open(item.revealTargets.first ?? item.url)
            }
        }
    }

    private var runningID: JobItem.ID? {
        model.store.items.first { $0.isRunning }?.id
    }
}

struct JobRow: View {
    let item: JobItem
    let canRemove: Bool
    var stampFresh = false
    var stampDelay = 0.0
    let onRemove: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(ConversionOptions.Keys.pdfFormat) private var pdfFormat = ConversionOptions.PDFFormat.markdown.rawValue
    @State private var showDetail = false
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 26, height: 26)
                .opacity(item.status == .pending || item.status == .done || item.isRunning ? 1 : 0.5)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.url.lastPathComponent)
                    .fontWeight(.medium)
                    .lineLimit(1).truncationMode(.middle)
                detailLine
                    .font(.caption)
                    .lineLimit(1).truncationMode(.middle)
                    .help(tooltip)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            actions
            if item.status == .pending, !targetFormats.isEmpty {
                FormatChips(formats: targetFormats)
            }
            if item.registered {
                SealStamp(animate: stampFresh, delay: stampDelay)
            }
            StatusBadge(status: item.status)
                .frame(width: 96, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
        .onHover { hovering = $0 }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: 2) {
            if item.detail != nil {
                RowButton("Xem chi tiết lỗi", systemImage: "exclamationmark.bubble", tint: Theme.failed) { showDetail = true }
                    .popover(isPresented: $showDetail, arrowEdge: .bottom) { ErrorDetail(item: item) }
            }
            if hovering {
                if let first = item.revealTargets.first {
                    RowButton("Mở kết quả", systemImage: "arrow.up.forward.app") { NSWorkspace.shared.open(first) }
                    RowButton("Hiện trong Finder", systemImage: "folder") {
                        NSWorkspace.shared.activateFileViewerSelecting(item.revealTargets)
                    }
                }
                if canRemove {
                    RowButton("Xoá khỏi danh sách", systemImage: "xmark.circle", action: onRemove)
                }
            }
        }
    }

    /// Dòng phụ: với văn bản hành chính là nhãn loại + số ký hiệu · ngày · người ký;
    /// khi đang chạy là biểu tượng bước đang làm; còn lại là dòng chữ trạng thái.
    @ViewBuilder private var detailLine: some View {
        if item.status == .done, let m = item.meta, let type = m.docType {
            HStack(spacing: 5) {
                Text(type)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(.quaternary, in: .rect(cornerRadius: 4))
                // Số ký hiệu và ngày luôn hiện đủ; tên người ký rút gọn trước khi thiếu chỗ.
                Group {
                    if let number = m.number { Text(number).fixedSize() }
                    if let date = m.displayDate { Text("· " + date).fixedSize() }
                    if let signer = m.signer { Text("· " + signer).truncationMode(.tail) }
                }
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        } else if item.isRunning {
            HStack(spacing: 4) {
                Image(systemName: stageSymbol)
                    .foregroundStyle(Theme.running)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                Text(subtitle).foregroundStyle(.secondary)
            }
        } else {
            Text(subtitle).foregroundStyle(subtitleStyle)
        }
    }

    private var stageSymbol: String {
        switch item.stage {
        case "analyze": "doc.text.magnifyingglass"
        case "markdown": "text.alignleft"
        case "docx": "doc.richtext"
        default: "hourglass"
        }
    }

    /// Đuôi các tệp đã tạo (bỏ thư mục ảnh).
    private var createdFormats: [String] {
        item.revealTargets.map { $0.pathExtension.uppercased() }
    }

    private var tooltip: String {
        if item.status == .pending { return (item.url.path as NSString).abbreviatingWithTildeInPath }
        guard let m = item.meta else { return subtitle }
        let formats = createdFormats.isEmpty ? nil : createdFormats.joined(separator: ", ")
        let fields: [(String, String?)] = [
            ("Loại văn bản", m.docType), ("Số, ký hiệu", m.number), ("Ngày ban hành", m.displayDate),
            ("Cơ quan ban hành", m.issuer), ("Người ký", m.signer), ("Chức vụ", m.position), ("Trích yếu", m.summary), ("Đã tạo", formats),
        ]
        return fields.compactMap { label, value in value.map { "\(label): \($0)" } }.joined(separator: "\n")
    }

    /// Đuôi tệp sẽ tạo ra, theo tuỳ chọn hiện tại (chỉ hiện khi tệp đang chờ).
    private var targetFormats: [String] {
        guard item.url.pathExtension.lowercased() == "pdf" else { return ["MD"] }
        switch ConversionOptions.PDFFormat(rawValue: pdfFormat) ?? .markdown {
        case .markdown: return ["MD"]
        case .word: return ["DOCX"]
        case .both: return ["MD", "DOCX"]
        }
    }

    /// Dòng phụ: thư mục chứa khi chờ; bước đang làm; kết quả; hoặc lý do lỗi/bỏ qua.
    private var subtitle: String {
        switch item.status {
        case .pending: return location
        case .running(let message): return message
        case .done:
            let kinds = item.revealTargets.map { "." + $0.pathExtension }
            // Văn bản hành chính: hiện ngay loại, số ký hiệu, ngày, người ký thay cho dòng "Đã tạo …".
            let headline = item.meta?.headline ?? ""
            var parts = [headline.isEmpty ? "Đã tạo " + (kinds.isEmpty ? "kết quả" : kinds.joined(separator: ", ")) : headline]
            if item.sourceTrashed { parts.append("tệp gốc đã vào Thùng rác") }
            if let note = item.note { parts.append(note) }
            return parts.joined(separator: " · ")
        case .failed(let message), .skipped(let message): return message
        case .cancelled: return location
        }
    }

    private var subtitleStyle: AnyShapeStyle {
        if case .failed = item.status { return AnyShapeStyle(Theme.failed) }
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

/// Nút biểu tượng nhỏ trong một dòng.
private struct RowButton: View {
    let title: String
    let systemImage: String
    var tint: Color = .secondary
    let action: () -> Void

    init(_ title: String, systemImage: String, tint: Color = .secondary, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(tint)
            .frame(width: 24, height: 22)
            .contentShape(.rect)
            .help(title)
    }
}

/// Nhãn định dạng đầu ra, ví dụ "→ MD DOCX".
struct FormatChips: View {
    let formats: [String]

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.right").font(.system(size: 8, weight: .bold)).foregroundStyle(.tertiary)
            ForEach(formats, id: \.self) { f in
                Text(f)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.running)
                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                    .background(Theme.running.opacity(0.12), in: .rect(cornerRadius: 4))
            }
        }
        .help("Định dạng sẽ tạo ra")
    }
}

extension JobItem {
    var isRunning: Bool { if case .running = status { true } else { false } }
}

struct StatusBadge: View {
    let status: JobItem.Status

    var body: some View {
        HStack(spacing: 4) {
            if case .running = status {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: symbol).imageScale(.small)
            }
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.13), in: .capsule)
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

    private var symbol: String {
        switch status {
        case .pending: "clock"
        case .running: "arrow.triangle.2.circlepath"
        case .done: "checkmark"
        case .failed: "exclamationmark.triangle.fill"
        case .skipped: "forward.fill"
        case .cancelled: "stop.fill"
        }
    }

    private var color: Color { Theme.color(for: status) }
}

private struct ErrorDetail: View {
    let item: JobItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(item.url.lastPathComponent, systemImage: "exclamationmark.triangle.fill")
                .font(.headline).foregroundStyle(Theme.failed)
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
