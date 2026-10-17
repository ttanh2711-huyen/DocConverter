import DocConverterKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            JobListView(store: model.store)
                .dropDestination(for: URL.self) { urls, _ in
                    model.store.add(files: urls.filter { !$0.hasDirectoryPath })
                    return true
                }
            Divider()
            HStack {
                Spacer()
                if model.store.isRunning {
                    ProgressView().controlSize(.small)
                    Button("Huỷ", role: .cancel) { model.cancel() }
                } else {
                    Button("Bắt đầu") { model.start() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(model.store.items.isEmpty)
                }
            }
            .padding(12)
        }
        .frame(minWidth: 640, minHeight: 420)
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
            ContentUnavailableView("Kéo thả tệp vào đây",
                                   systemImage: "arrow.down.doc",
                                   description: Text("PDF → Markdown/Word; Word, Excel, PowerPoint, HTML… → Markdown"))
        } else {
            List(store.items) { item in
                JobRow(item: item)
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
                Text(item.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                Text(statusText).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var statusText: String {
        switch item.status {
        case .pending: "Đang chờ"
        case .running(let message): message
        case .done: "Hoàn tất"
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
