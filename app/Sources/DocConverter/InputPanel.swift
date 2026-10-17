import AppKit
import DocConverterKit
import SwiftUI
import UniformTypeIdentifiers

/// Thanh nhập liệu: chọn tệp, chọn thư mục, tuỳ chọn thư mục con.
struct InputPanel: View {
    let store: JobStore
    @AppStorage("includeSubfolders") private var includeSubfolders = true

    var body: some View {
        HStack(spacing: 12) {
            Button("Chọn tệp…", systemImage: "doc.badge.plus") { pickFiles() }
            Button("Chọn thư mục…", systemImage: "folder.badge.plus") { pickFolder() }
            Toggle("Bao gồm thư mục con", isOn: $includeSubfolders)
            Spacer()
            if !store.items.isEmpty {
                Text("\(store.items.count) tệp").foregroundStyle(.secondary)
                Button("Xoá danh sách") { store.clear() }
                    .disabled(store.isRunning)
            }
        }
        .disabled(store.isRunning)
    }

    func add(_ urls: [URL]) {
        store.add(InputCollector.expand(urls, recursive: includeSubfolders))
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.title = "Chọn tệp cần chuyển đổi"
        panel.prompt = "Thêm"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = SupportedFormats.all.compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK { add(panel.urls) }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.title = "Chọn thư mục cần chuyển đổi"
        panel.prompt = "Thêm"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK { add(panel.urls) }
    }
}
