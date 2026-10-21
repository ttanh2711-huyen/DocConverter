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

/// Bố cục chính: thanh lọc + danh sách tệp ở giữa, bảng tuỳ chọn bên phải, thanh thao tác phía dưới.
struct MainView: View {
    @Bindable var model: AppModel
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if model.store.items.isEmpty {
                    EmptyDropView(model: model, targeted: dropTargeted)
                } else {
                    VStack(spacing: 0) {
                        ListHeader(model: model)
                        Divider()
                        JobListView(model: model)
                    }
                    .overlay {
                        if dropTargeted {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                                .background(Color.accentColor.opacity(0.07), in: .rect(cornerRadius: 12))
                                .overlay {
                                    Label("Thả để thêm vào danh sách", systemImage: "plus.circle.fill")
                                        .font(.headline)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(.regularMaterial, in: .capsule)
                                }
                                .padding(8)
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
            ActionBar(model: model)
        }
        .navigationTitle("DocConverter")
        .navigationSubtitle(subtitle)
        .toolbar { toolbar }
        .inspector(isPresented: $model.showInspector) {
            OptionsInspector(model: model)
                .disabled(model.store.isRunning)
                .inspectorColumnWidth(min: 280, ideal: 300, max: 360)
        }
    }

    private var subtitle: String {
        let s = model.store.summary
        guard s.total > 0 else { return "" }
        return model.store.isRunning ? "Đang chuyển đổi…" : "\(s.total) tệp"
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Menu {
                Button("Chọn tệp…", systemImage: "doc") { model.chooseFiles() }
                Button("Chọn thư mục…", systemImage: "folder") { model.chooseFolders() }
            } label: {
                Label("Thêm", systemImage: "plus")
            } primaryAction: {
                model.chooseFiles()
            }
            .help("Thêm tệp (⌘O). Bấm mũi tên để chọn thư mục (⇧⌘O)")
            .disabled(model.store.isRunning)
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Tuỳ chọn", systemImage: "sidebar.trailing") { model.showInspector.toggle() }
                .help("Ẩn/hiện bảng tuỳ chọn (⌥⌘I)")
        }
    }
}

/// Thanh trên danh sách: lọc theo trạng thái và dọn danh sách.
struct ListHeader: View {
    @Bindable var model: AppModel

    var body: some View {
        let s = model.store.summary
        HStack(spacing: 10) {
            Picker("Lọc", selection: $model.filter) {
                ForEach(ListFilter.allCases) { f in
                    Text("\(f.title) \(f.count(in: s))").monospacedDigit().tag(f)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help("Lọc danh sách theo trạng thái. \"Lỗi\" gồm cả tệp bị huỷ hoặc bỏ qua.")

            Spacer(minLength: 8)

            Menu {
                Button("Xoá mục đã hoàn tất", systemImage: "checkmark.circle") {
                    model.removeFinished { $0 == .done }
                }
                .disabled(s.done == 0)
                Button("Xoá mục bị bỏ qua", systemImage: "forward") {
                    model.removeFinished { if case .skipped = $0 { true } else { false } }
                }
                .disabled(s.skipped == 0)
                Divider()
                Button("Xoá mục đã chọn", systemImage: "minus.circle") { model.removeSelected() }
                    .disabled(model.selection.isEmpty)
                Button("Xoá cả danh sách", systemImage: "trash", role: .destructive) { model.clearList() }
            } label: {
                Label("Dọn danh sách", systemImage: "line.3.horizontal.decrease.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(!model.canEditList)
            .help("Xoá bớt mục khỏi danh sách (tệp trên ổ đĩa không bị ảnh hưởng)")
        }
        .controlSize(.small)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
