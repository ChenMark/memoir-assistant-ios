import Foundation
import Intents
import UIKit

// MARK: - Siri Shortcuts 管理器

@MainActor
final class SiriShortcutsManager: ObservableObject {
    static let shared = SiriShortcutsManager()

    @Published var pendingAction: SiriAction?

    // MARK: - 快捷指令类型

    enum SiriAction: String, CaseIterable {
        case recordMemoir = "com.memoir.assistant.record"
        case viewTodayMemoir = "com.memoir.assistant.today"
        case aiInterview = "com.memoir.assistant.interview"

        var title: String {
            switch self {
            case .recordMemoir: return "记录今天的回忆"
            case .viewTodayMemoir: return "看看今天的回忆"
            case .aiInterview: return "开始AI访谈"
            }
        }

        var suggestedPhrase: String {
            switch self {
            case .recordMemoir: return "记录今天的回忆"
            case .viewTodayMemoir: return "看看我的回忆"
            case .aiInterview: return "开始回忆访谈"
            }
        }

        var icon: String {
            switch self {
            case .recordMemoir: return "square.and.pencil"
            case .viewTodayMemoir: return "book.pages"
            case .aiInterview: return "bubble.left.and.bubble.right"
            }
        }

        /// 捐赠给 Siri 的建议短语列表
        var suggestedInvocationPhrases: [String] {
            switch self {
            case .recordMemoir:
                return [
                    "在忆往昔记录今天的回忆",
                    "写下今天的回忆",
                    "用忆往昔记录今天",
                    "回忆今天发生了什么",
                ]
            case .viewTodayMemoir:
                return [
                    "在忆往昔看看我的回忆",
                    "查看今天的回忆",
                    "看我的回忆录",
                ]
            case .aiInterview:
                return [
                    "在忆往昔开始AI访谈",
                    "和忆往昔聊聊",
                    "开始回忆访谈",
                ]
            }
        }
    }

    // MARK: - 捐赠快捷指令

    func donateShortcut(_ action: SiriAction) {
        let activity = NSUserActivity(activityType: action.rawValue)
        activity.title = action.title
        activity.suggestedInvocationPhrase = action.suggestedPhrase
        activity.persistentIdentifier = action.rawValue
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.isEligibleForPublicIndexing = true
        activity.isEligibleForHandoff = false

        // 设置关键词便于搜索
        activity.keywords = Set(["回忆录", "回忆", "记录", "AI", "访谈", "往昔"])

        // 设置关联内容属性
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.contentDescription = action.title
        attributes.keywords = ["回忆录", "AI"]
        activity.contentAttributeSet = attributes

        // 捐赠
        UIApplication.shared.userActivity = activity
        activity.becomeCurrent()

        print("[SiriShortcuts] 已捐赠快捷指令: \(action.title)")
    }

    /// 捐赠所有快捷指令（在登录后调用）
    func donateAllShortcuts() {
        for action in SiriAction.allCases {
            donateShortcut(action)
        }
    }

    // MARK: - 处理传入的快捷指令

    func handleUserActivity(_ activity: NSUserActivity) -> Bool {
        guard let action = SiriAction.allCases.first(where: {
            activity.activityType == $0.rawValue
        }) else {
            return false
        }

        print("[SiriShortcuts] 收到快捷指令: \(action.title)")
        pendingAction = action
        return true
    }

    /// 清除待处理动作
    func clearPendingAction() {
        pendingAction = nil
    }
}
