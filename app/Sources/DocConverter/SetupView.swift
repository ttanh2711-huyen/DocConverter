import DocConverterKit
import SwiftUI

/// Màn hình thiết lập môi trường ở lần mở đầu tiên.
struct SetupView: View {
    let environment: EnvironmentManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox").font(.system(size: 44)).foregroundStyle(.tint)
            Text("Chuẩn bị DocConverter").font(.title2.bold())
            switch environment.state {
            case .checking:
                ProgressView("Đang kiểm tra môi trường…")
            case .needsSetup:
                Text("Lần đầu sử dụng, DocConverter cần tải và cài các thư viện chuyển đổi (khoảng 2–3 GB). "
                     + "Việc này chỉ làm một lần; sau đó app chạy được khi không có mạng.")
                    .multilineTextAlignment(.center).frame(maxWidth: 460)
                Button("Bắt đầu thiết lập") { Task { await environment.install() } }
                    .keyboardShortcut(.defaultAction)
            case .installing(let step, let total, let title):
                ProgressView(value: Double(max(step - 1, 0)), total: Double(total)) {
                    Text("Bước \(step)/\(total): \(title)")
                }
                .frame(maxWidth: 460)
                logView
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).frame(maxWidth: 460)
                Button("Thử lại") { Task { await environment.install() } }
                    .keyboardShortcut(.defaultAction)
                logView
            case .ready:
                ProgressView()
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(environment.log.suffix(200).joined(separator: "\n"))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("end")
            }
            .frame(maxWidth: 560, maxHeight: 160)
            .onChange(of: environment.log.count) { proxy.scrollTo("end", anchor: .bottom) }
        }
    }
}
