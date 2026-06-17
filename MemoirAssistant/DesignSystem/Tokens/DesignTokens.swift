import SwiftUI

// MARK: - 忆往昔 iOS 设计令牌
// 基于 Web 端设计系统：怀旧写实风格，适配 50-80 岁中老年用户

enum DesignTokens {

    // MARK: - 间距系统 (8pt 基准)
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - 圆角
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 9999
    }

    // MARK: - 字体大小 (适老化：18px 起步)
    enum Typography {
        // 正文 — 18pt 起步，适配老花眼
        static let body: CGFloat = 18
        static let bodySmall: CGFloat = 15
        static let caption: CGFloat = 13
        // 标题
        static let title: CGFloat = 28
        static let title2: CGFloat = 22
        static let headline: CGFloat = 20
        // 辅助
        static let button: CGFloat = 18
        static let tab: CGFloat = 16
        static let badge: CGFloat = 12
    }

    // MARK: - 阴影
    enum Shadow {
        static let card: (color: Color, radius: CGFloat, y: CGFloat) =
            (.black.opacity(0.06), 8, 2)
        static let elevated: (color: Color, radius: CGFloat, y: CGFloat) =
            (.black.opacity(0.1), 16, 4)
        static let modal: (color: Color, radius: CGFloat, y: CGFloat) =
            (.black.opacity(0.15), 24, 8)
    }

    // MARK: - 动画
    enum Animation {
        static let `default`: SwiftUI.Animation = .easeInOut(duration: 0.25)
        static let spring: SwiftUI.Animation = .spring(response: 0.35, dampingFraction: 0.7)
        static let slow: SwiftUI.Animation = .easeInOut(duration: 0.4)
        static let pressDown: SwiftUI.Animation = .easeOut(duration: 0.1)
    }
}

// MARK: - 语义化颜色 (支持 Light / Dark)
struct MemoirColors {
    // 主色调 — 暖棕/琥珀系，呼应"怀旧"主题
    static let primary = Color("Primary")           // #8B5E3C 暖棕色
    static let primaryLight = Color("PrimaryLight")  // #C49A6C
    static let primaryDark = Color("PrimaryDark")    // #6B3F22

    // 背景 — 泛黄纸张色系
    static let background = Color("Background")      // Light: #FFF8F0, Dark: #1C1612
    static let surface = Color("Surface")            // Light: #FFFDF9, Dark: #2A221C
    static let card = Color("Card")                  // Light: #FFFFFF, Dark: #332A22

    // 文字
    static let textPrimary = Color("TextPrimary")    // Light: #3D2E1E, Dark: #E8D8C0
    static let textSecondary = Color("TextSecondary") // Light: #8B7355, Dark: #A89880
    static let textTertiary = Color("TextTertiary")  // Light: #B8A088, Dark: #7A6A55

    // 边框
    static let border = Color("Border")              // Light: #E0D5C5, Dark: #443A2E

    // 功能色
    static let success = Color("Success")            // #4CAF50
    static let warning = Color("Warning")            // #FF9800
    static let danger = Color("Danger")              // #E53935
    static let info = Color("Info")                  // #2196F3

    // 特殊背景纹理色
    static let wood = Color("Wood")                  // 木纹底色 #D4A574
    static let leather = Color("Leather")            // 皮革色 #8B4513
}
