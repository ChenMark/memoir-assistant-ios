import WidgetKit
import SwiftUI

// MARK: - Widget Timeline Entry

struct MemoirWidgetEntry: TimelineEntry {
    let date: Date
    let dailyMemoir: DailyMemoir?
    let recentMemoirs: [WidgetMemoirItem]
    let isPlaceholder: Bool

    static let placeholder = MemoirWidgetEntry(
        date: Date(),
        dailyMemoir: DailyMemoir(
            title: "那年夏天的冰棍",
            date: "1995-07-15",
            mood: "😊",
            excerpt: "记得小时候，每到夏天最期盼的就是冰棍车从巷口经过..."
        ),
        recentMemoirs: [
            WidgetMemoirItem(title: "小学第一天的书包", date: "1990-09-01"),
            WidgetMemoirItem(title: "第一次骑自行车", date: "1992-05-20"),
        ],
        isPlaceholder: true
    )
}

struct DailyMemoir: Codable {
    let title: String
    let date: String
    let mood: String?
    let excerpt: String
}

struct WidgetMemoirItem: Codable, Identifiable {
    let title: String
    let date: String
    var id: String { "\(title)_\(date)" }
}
