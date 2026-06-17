import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct MemoirWidgetProvider: TimelineProvider {
    typealias Entry = MemoirWidgetEntry

    // 占位（骨架屏）
    func placeholder(in context: Context) -> MemoirWidgetEntry {
        .placeholder
    }

    // 快照（预览用）
    func getSnapshot(in context: Context, completion: @escaping (MemoirWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task {
            let entry = await fetchWidgetData()
            completion(entry)
        }
    }

    // 时间线（定时刷新）
    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoirWidgetEntry>) -> Void) {
        Task {
            let entry = await fetchWidgetData()

            // 每小时刷新一次
            let nextUpdate = Calendar.current.date(
                byAdding: .hour,
                value: 1,
                to: Date()
            ) ?? Date().addingTimeInterval(3600)

            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    // MARK: - 拉取数据

    private func fetchWidgetData() async -> MemoirWidgetEntry {
        // 从 App Group UserDefaults 读取共享数据
        let sharedDefaults = UserDefaults(suiteName: "group.com.memoir.assistant")
        let dailyData = sharedDefaults?.data(forKey: "widget_daily_memoir")
        let recentData = sharedDefaults?.data(forKey: "widget_recent_memoirs")

        let dailyMemoir: DailyMemoir? = {
            guard let data = dailyData else { return nil }
            return try? JSONDecoder().decode(DailyMemoir.self, from: data)
        }()

        let recentMemoirs: [WidgetMemoirItem] = {
            guard let data = recentData else { return [] }
            return (try? JSONDecoder().decode([WidgetMemoirItem].self, from: data)) ?? []
        }()

        return MemoirWidgetEntry(
            date: Date(),
            dailyMemoir: dailyMemoir,
            recentMemoirs: recentMemoirs,
            isPlaceholder: false
        )
    }
}
