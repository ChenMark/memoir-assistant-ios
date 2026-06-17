import SwiftUI
import WidgetKit

// MARK: - Widget 视图

struct MemoirWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: MemoirWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Medium Widget (今日回忆)

struct MediumWidgetView: View {
    let entry: MemoirWidgetEntry

    var body: some View {
        ZStack {
            // 仿纸张背景
            Color(red: 1.0, green: 0.97, blue: 0.94)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 8) {
                // 顶部
                HStack {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.55, green: 0.37, blue: 0.24))
                    Text("忆往昔")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 0.36, green: 0.22, blue: 0.13))
                    Spacer()
                    Text(formattedDate)
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.55, green: 0.45, blue: 0.33))
                }

                Divider()
                    .background(Color(red: 0.88, green: 0.84, blue: 0.77))

                if let memoir = entry.dailyMemoir {
                    // 今日回忆
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("历史上的今天")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.37, blue: 0.24))
                            if let mood = memoir.mood {
                                Text(mood)
                                    .font(.system(size: 13))
                            }
                        }

                        Text(memoir.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(red: 0.36, green: 0.22, blue: 0.13))
                            .lineLimit(1)

                        Text(memoir.excerpt)
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.55, green: 0.45, blue: 0.33))
                            .lineLimit(2)
                    }
                } else {
                    // 无回忆提示
                    VStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 22))
                            .foregroundColor(Color(red: 0.55, green: 0.37, blue: 0.24).opacity(0.4))
                        Text("今天还没有回忆记录")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.55, green: 0.45, blue: 0.33))
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 11))
                            Text("点击记录今天的故事")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(Color(red: 0.55, green: 0.37, blue: 0.24))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日"
        return fmt.string(from: entry.date)
    }
}

// MARK: - Large Widget (每日回忆 + 最近列表)

struct LargeWidgetView: View {
    let entry: MemoirWidgetEntry

    var body: some View {
        ZStack {
            Color(red: 1.0, green: 0.97, blue: 0.94)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                // 顶部标题栏
                HStack {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 0.55, green: 0.37, blue: 0.24))
                    Text("忆往昔")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(red: 0.36, green: 0.22, blue: 0.13))
                    Spacer()
                    Label("回忆录", systemImage: "app")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.55, green: 0.45, blue: 0.33))
                }

                Divider()
                    .background(Color(red: 0.88, green: 0.84, blue: 0.77))

                if let memoir = entry.dailyMemoir {
                    // 今天的回忆
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("📅 历史上的今天")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.37, blue: 0.24))
                            if let mood = memoir.mood {
                                Text(mood)
                                    .font(.system(size: 14))
                            }
                        }

                        Text(memoir.title)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(Color(red: 0.36, green: 0.22, blue: 0.13))

                        Text(memoir.excerpt)
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.55, green: 0.45, blue: 0.33))
                            .lineLimit(3)
                    }
                    .padding(12)
                    .background(
                        Color.white.opacity(0.6)
                            .cornerRadius(12)
                    )
                } else {
                    // 快速记录入口
                    HStack {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("开始写回忆录")
                                .font(.system(size: 15, weight: .semibold))
                            Text("记录今天发生的故事")
                                .font(.system(size: 12))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(Color(red: 0.36, green: 0.22, blue: 0.13))
                    .padding(12)
                    .background(
                        Color(red: 0.55, green: 0.37, blue: 0.24).opacity(0.08)
                            .cornerRadius(12)
                    )
                }

                // 最近回忆录
                if !entry.recentMemoirs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("最近回忆录")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(red: 0.55, green: 0.45, blue: 0.33))

                        ForEach(entry.recentMemoirs.prefix(3)) { item in
                            HStack {
                                Circle()
                                    .fill(Color(red: 0.55, green: 0.37, blue: 0.24).opacity(0.3))
                                    .frame(width: 6, height: 6)
                                Text(item.title)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.36, green: 0.22, blue: 0.13))
                                    .lineLimit(1)
                                Spacer()
                                Text(item.date)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(red: 0.55, green: 0.45, blue: 0.33))
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }
}

// MARK: - Widget 定义

struct MemoirWidget: Widget {
    let kind = "com.memoir.assistant.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: MemoirWidgetProvider()
        ) { entry in
            MemoirWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("每日回忆")
        .description("在桌面查看今天的回忆，或快速开始记录")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Preview

#Preview("Medium", as: .systemMedium) {
    MemoirWidget()
} timeline: {
    MemoirWidgetEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    MemoirWidget()
} timeline: {
    MemoirWidgetEntry.placeholder
}
