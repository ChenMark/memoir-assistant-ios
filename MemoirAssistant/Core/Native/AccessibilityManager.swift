import SwiftUI

// MARK: - 无障碍管理器 — 大字号 / 高对比度 / 减少动效

@MainActor
final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()

    // 大字号模式 (0=标准, 1=大号, 2=超大)
    @AppStorage("accessibility_font_scale") var fontScale: Double = 0 {
        didSet { applyScale() }
    }

    // 高对比度模式
    @AppStorage("accessibility_high_contrast") var highContrast: Bool = false {
        didSet { applyScale() }
    }

    // 减少动效
    @AppStorage("accessibility_reduce_motion") var reduceMotion: Bool = false {
        didSet { applyScale() }
    }

    // 粗体文本
    @AppStorage("accessibility_bold_text") var boldText: Bool = false

    // 按钮最小高度
    @AppStorage("accessibility_large_touch_targets") var largeTouchTargets: Bool = false

    // 当前缩放倍数
    @Published var currentScaleFactor: CGFloat = 1.0

    // MARK: - 字号缩放映射

    /// 根据 scale 返回缩放倍数
    var scaleMultiplier: CGFloat {
        switch fontScale {
        case 0: return 1.0    // 标准 18pt
        case 1: return 1.33   // 大号 ~24pt
        case 2: return 1.67   // 超大 ~30pt
        default: return 1.0
        }
    }

    /// 缩放后的字号
    func scaledFont(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> Font {
        let size = baseSize * scaleMultiplier
        if boldText {
            return .system(size: size, weight: .bold)
        }
        return .system(size: size, weight: weight)
    }

    /// 缩放后的间距
    func scaledSpacing(_ base: CGFloat) -> CGFloat {
        base * scaleMultiplier
    }

    /// 缩放后的按钮高度
    func scaledButtonHeight(_ base: CGFloat) -> CGFloat {
        if largeTouchTargets { return max(base * scaleMultiplier, 56) }
        return base * scaleMultiplier
    }

    // MARK: - 动画时长

    var animationDuration: CGFloat {
        reduceMotion ? 0 : 0.25
    }

    var springAnimation: SwiftUI.Animation {
        if reduceMotion {
            return .easeInOut(duration: 0)
        }
        return .spring(response: 0.35, dampingFraction: 0.7)
    }

    // MARK: - 应用

    private func applyScale() {
        currentScaleFactor = scaleMultiplier
    }

    /// 在 App 启动时调用
    func setupOnLaunch() {
        applyScale()
        // 监听系统 DynamicType 变化
        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyScale()
            }
        }
    }
}
