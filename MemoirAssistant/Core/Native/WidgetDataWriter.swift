import Foundation
import WidgetKit

// MARK: - Widget 数据同步器 — 将精选数据写入 App Group UserDefaults

@MainActor
final class WidgetDataWriter {
    static let shared = WidgetDataWriter()

    private let sharedDefaults = UserDefaults(suiteName: "group.com.memoir.assistant")
    private let memoirService = MemoirService.shared

    /// 刷新 Widget 数据
    func refreshWidgetData() async {
        do {
            // 获取最近 10 篇回忆录
            let response = try await memoirService.fetchMemoirs(page: 1, limit: 10)
            let memoirs = response.data

            // 找今天日期对应的历史回忆（模拟"历史上的今天"）
            let today = Calendar.current.dateComponents([.month, .day], from: Date())
            let dailyMemoir = memoirs.first { memoir in
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                guard let date = fmt.date(from: memoir.date) else { return false }
                let comps = Calendar.current.dateComponents([.month, .day], from: date)
                return comps.month == today.month && comps.day == today.day
            }

            // 构建 DailyMemoir
            let dailyEntry: DailyMemoir? = {
                guard let memoir = dailyMemoir else { return nil }
                return DailyMemoir(
                    title: memoir.title,
                    date: memoir.date,
                    mood: memoir.mood,
                    excerpt: String(memoir.content.prefix(80))
                )
            }()

            // 最近的回忆录列表（排除今天那篇）
            let recentItems = memoirs
                .filter { $0.id != dailyMemoir?.title } // 简单去重
                .prefix(5)
                .map { WidgetMemoirItem(title: $0.title, date: $0.date) }

            // 写入 App Group UserDefaults
            if let daily = dailyEntry,
               let dailyData = try? JSONEncoder().encode(daily) {
                sharedDefaults?.set(dailyData, forKey: "widget_daily_memoir")
            } else {
                sharedDefaults?.removeObject(forKey: "widget_daily_memoir")
            }

            if let recentData = try? JSONEncoder().encode(recentItems) {
                sharedDefaults?.set(recentData, forKey: "widget_recent_memoirs")
            }

            // 触发 Widget 刷新
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("[WidgetDataWriter] 刷新失败: \(error.localizedDescription)")
        }
    }

    /// 在 Dashboard 加载完成后调用
    func refreshIfNeeded() {
        let lastRefresh = sharedDefaults?.double(forKey: "widget_last_refresh") ?? 0
        let now = Date().timeIntervalSince1970

        // 10分钟间隔刷新
        if now - lastRefresh > 600 {
            sharedDefaults?.set(now, forKey: "widget_last_refresh")
            Task { await refreshWidgetData() }
        }
    }
}
