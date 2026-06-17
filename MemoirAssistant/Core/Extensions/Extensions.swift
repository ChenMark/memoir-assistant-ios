import SwiftUI

// MARK: - View 扩展：卡片样式
extension View {
    /// 怀旧写实风格卡片
    func memoirCard() -> some View {
        self
            .padding(DesignTokens.Spacing.lg)
            .background(MemoirColors.card)
            .cornerRadius(DesignTokens.Radius.lg)
            .shadow(
                color: MemoirColors.primary.opacity(0.08),
                radius: DesignTokens.Shadow.card.radius,
                y: DesignTokens.Shadow.card.y
            )
    }

    /// 按压缩放效果
    func pressableScale(_ scale: CGFloat = 0.97) -> some View {
        self.modifier(PressableScaleModifier(scale: scale))
    }

    /// 适老化阅读样式（正文）
    func memoirBodyStyle() -> some View {
        self
            .font(.system(size: DesignTokens.Typography.body))
            .foregroundColor(MemoirColors.textPrimary)
            .lineSpacing(6)
    }
}

// MARK: - 按压缩放 Modifier
struct PressableScaleModifier: ViewModifier {
    let scale: CGFloat
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(DesignTokens.Animation.pressDown, value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 50,
                pressing: { pressing in
                    withAnimation { isPressed = pressing }
                }, perform: {})
    }
}

// MARK: - Date 扩展
extension Date {
    func memoirFormatted() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    func relativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - String 扩展
extension String {
    var isValidEmail: Bool {
        let regex = try? NSRegularExpression(
            pattern: "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$",
            options: .caseInsensitive
        )
        return regex?.firstMatch(in: self, range: NSRange(location: 0, length: count)) != nil
    }

    var isValidChinesePhone: Bool {
        let regex = try? NSRegularExpression(pattern: "^1[3-9]\\d{9}$")
        return regex?.firstMatch(in: self, range: NSRange(location: 0, length: count)) != nil
    }
}

// MARK: - Color 扩展
extension Color {
    static let memoirPrimary = MemoirColors.primary
    static let memoirBackground = MemoirColors.background
    static let memoirSurface = MemoirColors.surface
    static let memoirTextPrimary = MemoirColors.textPrimary
    static let memoirTextSecondary = MemoirColors.textSecondary
}
