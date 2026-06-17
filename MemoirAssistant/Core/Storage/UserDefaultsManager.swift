import Foundation

/// 本地偏好存储（非敏感配置）
final class UserDefaultsManager {
    static let shared = UserDefaultsManager()

    private let defaults = UserDefaults(suiteName: "group.com.memoir.assistant") ?? .standard

    private init() {}

    // MARK: - 用户偏好
    var fontSizeScale: CGFloat {
        get { CGFloat(defaults.float(forKey: "font_size_scale").clamped(to: 0.8...1.5)) }
        set { defaults.set(Float(newValue), forKey: "font_size_scale") }
    }

    var useHighContrast: Bool {
        get { defaults.bool(forKey: "use_high_contrast") }
        set { defaults.set(newValue, forKey: "use_high_contrast") }
    }

    var hapticFeedbackEnabled: Bool {
        get { defaults.bool(forKey: "haptic_feedback_enabled") }
        set { defaults.set(newValue, forKey: "haptic_feedback_enabled") }
    }

    var lastSyncDate: Date? {
        get { defaults.object(forKey: "last_sync_date") as? Date }
        set { defaults.set(newValue, forKey: "last_sync_date") }
    }

    // MARK: - 应用状态
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "onboarding_completed") }
        set { defaults.set(newValue, forKey: "onboarding_completed") }
    }

    var selectedTab: Int {
        get { defaults.integer(forKey: "selected_tab") }
        set { defaults.set(newValue, forKey: "selected_tab") }
    }
}

// MARK: - Float 安全范围扩展
private extension Float {
    func clamped(to range: ClosedRange<CGFloat>) -> Float {
        Float(CGFloat(self).clamped(to: range))
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
