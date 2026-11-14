import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    /// Màu đổi theo giao diện sáng / tối.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

/// Bảng màu và kiểu chữ riêng của ứng dụng.
enum Theme {
    static let bg = Color(light: 0xF1F3F9, dark: 0x0D1020)
    static let card = Color(light: 0xFFFFFF, dark: 0x181C33)
    static let ink = Color(light: 0x141A2E, dark: 0xF0F2FB)
    static let muted = Color(light: 0x5A627D, dark: 0xA0A8C4)
    static let line = Color(light: 0xDDE1ED, dark: 0x2A2F4D)
    /// Màu nhấn duy nhất: nút gửi và nhãn ưu tiên cao.
    static let mark = Color(light: 0xFFC53D, dark: 0xFFC53D)
    static let onMark = Color(light: 0x141A2E, dark: 0x141A2E)
    /// Thanh nhập bằng lời.
    static let bar = Color(light: 0x141A2E, dark: 0x262B4A)
    static let onBar = Color(light: 0xF4F6FC, dark: 0xF4F6FC)
    static let barMuted = Color(light: 0xA3ABC6, dark: 0xA3ABC6)
    static let red = Color(light: 0xC62F3B, dark: 0xFF7480)
    static let green = Color(light: 0x17966B, dark: 0x4FD3A3)

    static let display = Font.system(size: 34, weight: .heavy)
    static let dayTitle = Font.system(size: 22, weight: .heavy)
    static let eyebrow = Font.system(size: 12, weight: .semibold)
}

/// "45p", "1g 30p".
func durationText(_ minutes: Int) -> String {
    guard minutes >= 60 else { return "\(minutes)p" }
    let rest = minutes % 60
    return rest == 0 ? "\(minutes / 60)g" : "\(minutes / 60)g \(rest)p"
}

func shortDateText(_ date: Date) -> String {
    date.formatted(.dateTime.weekday(.abbreviated).day().month(.defaultDigits).hour().minute())
}

struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(Theme.eyebrow)
            .tracking(1)
            .foregroundStyle(Theme.muted)
    }
}

struct TagView: View {
    enum Style {
        case plain
        case category(Color)
        case late
        case highlight
    }

    let text: String
    var style: Style = .plain

    private var foreground: Color {
        switch style {
        case .plain: return Theme.muted
        case .category(let color): return color
        case .late: return Theme.red
        case .highlight: return Theme.onMark
        }
    }

    private var background: Color {
        switch style {
        case .highlight: return Theme.mark
        default: return foreground.opacity(0.14)
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(background, in: RoundedRectangle(cornerRadius: 7))
    }
}

struct CheckBox: View {
    let isOn: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 9)
                .fill(isOn ? color : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(color, lineWidth: 2))
                .overlay {
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Theme.card)
                    }
                }
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "Đánh dấu chưa xong" : "Đánh dấu đã xong")
    }
}

/// Xếp các nhãn thành nhiều dòng khi không đủ chỗ.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let points = arrange(subviews, width: bounds.width).points
        for (index, point) in points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (size: CGSize, points: [CGPoint]) {
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), points)
    }
}
