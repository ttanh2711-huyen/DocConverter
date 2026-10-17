import DocConverterKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var model: AppModel
    @AppStorage("includeSubfolders") private var includeSubfolders = true
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            InputPanel(store: model.store)
                .padding(12)
            Divider()
            OutputOptionsView()
                .disabled(model.store.isRunning)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            JobListView(store: model.store)
                .overlay {
                    if dropTargeted {
                        RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentColor, lineWidth: 3).padding(4)
                    }
                }
                .dropDestination(for: URL.self) { urls, _ in
                    guard !model.store.isRunning else { return false }
                    model.store.add(InputCollector.expand(urls, recursive: includeSubfolders))
                    return true
                } isTargeted: { dropTargeted = $0 }
            Divider()
            HStack {
                Spacer()
                if model.store.isRunning {
                    ProgressView().controlSize(.small)
                    Button("Huỷ", role: .cancel) { model.cancel() }
                } else {
                    Button("Bắt đầu") { model.start() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(model.store.pendingJobs.isEmpty)
                }
            }
            .padding(12)
        }
        .frame(minWidth: 720, minHeight: 480)
        .task { SelfTest.run(model) }
        .alert("Không thể chuyển đổi", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text(model.alert ?? "")
        }
    }
}

struct JobListView: View {
    let store: JobStore

    var body: some View {
        if store.items.isEmpty {
            ContentUnavailableView("Kéo thả tệp hoặc thư mục vào đây",
                                   systemImage: "arrow.down.doc",
                                   description: Text("PDF → Markdown/Word; Word, Excel, PowerPoint, HTML… → Markdown"))
        } else {
            List(store.items) { item in
                JobRow(item: item)
                    .contextMenu {
                        Button("Xoá khỏi danh sách") { store.remove(item.id) }
                            .disabled(store.isRunning)
                    }
            }
        }
    }
}

struct JobRow: View {
    let item: JobItem

    var body: some View {
        HStack(spacing: 10) {
            statusIcon.frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName).lineLimit(1).truncationMode(.middle)
                Text(statusText).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    /// Tên tệp, kèm thư mục con tương đối nếu tệp nằm sâu trong thư mục đã chọn.
    private var displayName: String {
        let parent = item.url.deletingLastPathComponent().path
        guard parent != item.base.path, parent.hasPrefix(item.base.path + "/") else { return item.url.lastPathComponent }
        return String(item.url.path.dropFirst(item.base.path.count + 1))
    }

    private var statusText: String {
        switch item.status {
        case .pending: "Đang chờ"
        case .running(let message): message
        case .done:
            ["Hoàn tất", item.sourceTrashed ? "đã đưa tệp gốc vào Thùng rác" : nil, item.note]
                .compactMap { $0 }.joined(separator: " · ")
        case .failed(let message): message
        case .skipped(let message): message
        case .cancelled: "Đã huỷ"
        }
    }

    @ViewBuilder private var statusIcon: some View {
        switch item.status {
        case .pending: Image(systemName: "clock").foregroundStyle(.secondary)
        case .running: ProgressView().controlSize(.small)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        case .skipped: Image(systemName: "forward.fill").foregroundStyle(.secondary)
        case .cancelled: Image(systemName: "xmark.circle").foregroundStyle(.secondary)
        }
    }
}
