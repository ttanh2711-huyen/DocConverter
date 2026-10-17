import DocConverterKit
import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if model.isReady {
                MainView(model: model)
            } else {
                SetupView(environment: model.environment)
            }
        }
        .frame(minWidth: 860, minHeight: 540)
        .task { await model.environment.refresh() }
        .onChange(of: model.environment.state) { _, state in
            switch state {
            case .ready: SelfTest.run(model)
            case .needsSetup: SelfTest.snapshotSetupScreen()
            default: break
            }
        }
        .alert("Không thể chuyển đổi", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text(model.alert ?? "")
        }
    }
}

/// Bố cục chính: danh sách tệp ở giữa, bảng tuỳ chọn bên phải, thanh trạng thái phía dưới.
struct MainView: View {
    @Bindable var model: AppModel
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if model.store.items.isEmpty {
                    EmptyDropView(model: model, targeted: dropTargeted)
                } else {
                    JobListView(model: model)
                        .overlay {
                            if dropTargeted {
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.accentColor, lineWidth: 2)
                                    .background(Color.accentColor.opacity(0.06), in: .rect(cornerRadius: 10))
                                    .padding(6)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dropDestination(for: URL.self) { urls, _ in
                guard !model.store.isRunning else { return false }
                model.add(urls)
                return true
            } isTargeted: { dropTargeted = $0 }

            Divider()
            StatusBar(model: model)
        }
        .navigationTitle("DocConverter")
        .toolbar { toolbar }
        .inspector(isPresented: $model.showInspector) {
            OptionsInspector()
                .disabled(model.store.isRunning)
                .inspectorColumnWidth(min: 280, ideal: 310, max: 380)
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Menu {
                Button("Chọn tệp…", systemImage: "doc") { model.chooseFiles() }
                Button("Chọn thư mục…", systemImage: "folder") { model.chooseFolders() }
            } label: {
                Label("Thêm", systemImage: "plus")
            } primaryAction: {
                model.chooseFiles()
            }
            .help("Thêm tệp (⌘O). Giữ để chọn thư mục (⇧⌘O)")
            .disabled(model.store.isRunning)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Xoá mục đã chọn", systemImage: "minus.circle") { model.removeSelected() }
                .help("Xoá các tệp đã chọn khỏi danh sách (⌫)")
                .disabled(model.selection.isEmpty || model.store.isRunning)
            Button("Xoá danh sách", systemImage: "xmark.bin") { model.clearList() }
                .help("Xoá toàn bộ danh sách (⇧⌘⌫)")
                .disabled(!model.canEditList)
            Button("Tuỳ chọn", systemImage: "sidebar.right") { model.showInspector.toggle() }
                .help("Ẩn/hiện bảng tuỳ chọn (⌥⌘I)")
        }
    }
}
