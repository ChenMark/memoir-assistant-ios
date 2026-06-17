import SwiftUI

// MARK: - 主按钮样式（暖棕怀旧风）
struct PrimaryButtonStyle: ButtonStyle {
    var size: ButtonSize = .medium
    var fullWidth: Bool = false

    enum ButtonSize {
        case small, medium, large
        var height: CGFloat {
            switch self {
            case .small: return 40
            case .medium: return 52
            case .large: return 60
            }
        }
        var fontSize: CGFloat {
            switch self {
            case .small: return 15
            case .medium: return 18
            case .large: return 20
            }
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.fontSize, weight: .semibold))
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: size.height)
            .padding(.horizontal, fullWidth ? 0 : DesignTokens.Spacing.lg)
            .background(
                configuration.isPressed
                    ? MemoirColors.primaryDark
                    : MemoirColors.primary
            )
            .foregroundColor(.white)
            .cornerRadius(DesignTokens.Radius.md)
            .shadow(color: MemoirColors.primary.opacity(configuration.isPressed ? 0.15 : 0.3),
                    radius: configuration.isPressed ? 4 : 8,
                    y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignTokens.Animation.pressDown, value: configuration.isPressed)
    }
}

// MARK: - 次级按钮样式
struct SecondaryButtonStyle: ButtonStyle {
    var size: PrimaryButtonStyle.ButtonSize = .medium

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.fontSize, weight: .medium))
            .frame(height: size.height)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .background(
                configuration.isPressed
                    ? MemoirColors.border
                    : MemoirColors.surface
            )
            .foregroundColor(MemoirColors.primary)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(MemoirColors.primary, lineWidth: 1.5)
            )
            .cornerRadius(DesignTokens.Radius.md)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignTokens.Animation.pressDown, value: configuration.isPressed)
    }
}

// MARK: - 按钮样式扩展
extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var primaryLarge: PrimaryButtonStyle { PrimaryButtonStyle(size: .large, fullWidth: true) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
