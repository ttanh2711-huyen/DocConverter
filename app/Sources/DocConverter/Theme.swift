import AppKit
import DocConverterKit
import SwiftUI

/// Màu của app, mỗi màu một nghĩa; đều có biến thể sáng/tối và tăng tương phản.
/// Nút và điều khiển dùng màu nhấn của hệ thống; các màu dưới đây chỉ nằm trong nội dung.
enum Theme {
    /// Mực dấu văn thư (tím): chỉ dùng cho "đã vào sổ tổng hợp".
    /// Chữ trên nền trắng 8,2:1, trên nền nhạt của chính nó 6,7:1; giao diện tối 7,1:1 và 5,3:1.
    static let seal = dynamic(light: 0x4B3FA8, dark: 0xA99CFF, lightHigh: 0x352B8C, darkHigh: 0xC4BBFF)

    // Chữ của nhãn trạng thái, tối hơn màu hệ thống ở giao diện sáng để đạt 4,5:1 trên nền nhạt 13%.
    static let done = dynamic(light: 0x137030, dark: 0x32D74B, lightHigh: 0x0B5A24, darkHigh: 0x5CE070)
    static let running = dynamic(light: 0x0062CC, dark: 0x409CFF, lightHigh: 0x004A9E, darkHigh: 0x70B4FF)
    static let failed = dynamic(light: 0xC4261D, dark: 0xFF6961, lightHigh: 0x9E1A13, darkHigh: 0xFF8A84)
    static let cancelled = dynamic(light: 0x9A5200, dark: 0xFFB340, lightHigh: 0x7A4100, darkHigh: 0xFFC56E)
    static let neutral = dynamic(light: 0x5C5C61, dark: 0xAEAEB2, lightHigh: 0x3A3A3E, darkHigh: 0xD1D1D6)

    static func color(for status: JobItem.Status) -> Color {
        switch status {
        case .pending, .skipped: neutral
        case .running: running
        case .done: done
        case .failed: failed
        case .cancelled: cancelled
        }
    }

    private static func dynamic(light: UInt32, dark: UInt32, lightHigh: UInt32, darkHigh: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let high = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            return rgb(isDark ? (high ? darkHigh : dark) : (high ? lightHigh : light))
        })
    }

    private static func rgb(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Con dấu "VÀO SỔ": dấu hiệu riêng của app, đóng lên dòng văn bản khi được ghi vào sổ tổng hợp.
/// Hiệu ứng đóng dấu chạy một lần mỗi lô; khi bật Giảm chuyển động thì chỉ hiện dần.
struct SealStamp: View {
    var animate = true
    var delay = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    var body: some View {
        Text("VÀO SỔ")
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(Theme.seal)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Theme.seal.opacity(0.1), in: .rect(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.seal, lineWidth: 1.25)
                    .overlay(RoundedRectangle(cornerRadius: 5.5).strokeBorder(Theme.seal.opacity(0.5), lineWidth: 0.75)
                        .padding(-2.5))
            }
            .rotationEffect(.degrees(pressed || !animate ? -7 : (reduceMotion ? -7 : -22)))
            .scaleEffect(pressed || !animate || reduceMotion ? 1 : 1.9)
            .opacity(pressed || !animate ? 1 : 0)
            .padding(4)
            .onAppear {
                guard animate else { return }
                withAnimation((reduceMotion ? Animation.easeOut(duration: 0.2) : .spring(duration: 0.32, bounce: 0.35))
                    .delay(delay)) {
                    pressed = true
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Đã ghi vào sổ tổng hợp")
            .help("Đã ghi vào sổ tổng hợp (⇧⌘E để mở sổ)")
    }
}

/// Ô biểu tượng màu cho tiêu đề mục, theo kiểu Cài đặt hệ thống.
struct IconTile: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(color.gradient, in: .rect(cornerRadius: 5))
            .accessibilityHidden(true)
    }
}
