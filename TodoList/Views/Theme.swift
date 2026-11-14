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

/// "45p", "1g 30p" (tiếng Việt) hoặc "45m", "1h 30m" (tiếng Anh).
func durationText(_ minutes: Int) -> String {
    let hour = L("g", "h")
    let minute = L("p", "m")
    guard minutes >= 60 else { return "\(minutes)\(minute)" }
    let rest = minutes % 60
    return rest == 0 ? "\(minutes / 60)\(hour)" : "\(minutes / 60)\(hour) \(rest)\(minute)"
}

func shortDateText(_ date: Date) -> String {
    date.formatted(
        Date.FormatStyle().weekday(.abbreviated).day().month(.defaultDigits).hour().minute()
            .locale(AppLanguage.current.locale)
    )
}

func timeText(_ date: Date) -> String {
    date.formatted(Date.FormatStyle().hour().minute().locale(AppLanguage.current.locale))
}

func dayText(_ date: Date, weekdayOnly: Bool = false) -> String {
    let style = weekdayOnly
        ? Date.FormatStyle().weekday(.wide)
        : Date.FormatStyle().weekday(.wide).day().month(.wide)
    return date.formatted(style.locale(AppLanguage.current.locale))
}

/// Thẻ thông báo viền mực dùng chung cho các màn hình.
struct Banner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.ink, lineWidth: 1.5))
    }
}

/// Nút chính màu vàng.
struct PrimaryLabel: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(Theme.onMark)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(Theme.mark, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Nút micro: đọc để nhập, văn bản hiện vào ô để người dùng sửa trước khi gửi.
struct MicButton: View {
    @Binding var text: String
    var tint: Color = Theme.ink
    @StateObject private var recognizer = SpeechRecognizer()
    @State private var base = ""

    var body: some View {
        Button {
            if !recognizer.isRecording { base = text.isEmpty ? "" : text + " " }
            recognizer.toggle()
        } label: {
            Image(systemName: recognizer.isRecording ? "stop.circle.fill" : "mic.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(recognizer.isRecording ? Theme.red : tint)
                .frame(width: 36, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recognizer.isRecording ? L("Dừng ghi âm", "Stop recording") : L("Nhập bằng giọng nói", "Dictate"))
        .onChange(of: recognizer.transcript) { _, transcript in
            if recognizer.isRecording || !transcript.isEmpty { text = base + transcript }
        }
        .alert(
            L("Giọng nói", "Voice"),
            isPresented: Binding(get: { recognizer.errorText != nil }, set: { if !$0 { recognizer.errorText = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(recognizer.errorText ?? "")
        }
    }
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
        .accessibilityLabel(isOn ? L("Đánh dấu chưa xong", "Mark as not done") : L("Đánh dấu đã xong", "Mark as done"))
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
