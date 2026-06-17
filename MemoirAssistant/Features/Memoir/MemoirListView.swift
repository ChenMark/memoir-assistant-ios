import SwiftUI

// MARK: - 回忆录列表页 (时间线 + 下拉刷新 + 分页)

struct MemoirListView: View {
    @StateObject private var viewModel = MemoirListViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                MemoirColors.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.memoirs.isEmpty {
                    loadingView
                } else if viewModel.memoirs.isEmpty && !viewModel.isLoading {
                    emptyView
                } else {
                    timelineList
                }
            }
            .navigationTitle("回忆录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        NavigationLink(destination: SearchFilterView()) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(MemoirColors.primary)
                        }

                        NavigationLink(destination: DraftListView()) {
                            Image(systemName: "tray.full")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(MemoirColors.primary)
                        }

                        NavigationLink(destination: MemoirEditorView()) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(MemoirColors.primary)
                        }
                    }
                }
            }
            .task {
                await viewModel.loadInitial()
            }
        }
    }

    // MARK: - 时间线列表

    private var timelineList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 下拉刷新指示器
                if viewModel.isRefreshing {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, DesignTokens.Spacing.md)
                        Spacer()
                    }
                }

                ForEach(Array(viewModel.groupedMemoirs.enumerated()), id: \.offset) { groupIndex, group in
                    timelineSection(date: group.key, memoirs: group.value, isLast: groupIndex == viewModel.groupedMemoirs.count - 1)
                }

                // 加载更多
                if viewModel.hasMore {
                    ProgressView()
                        .padding()
                        .onAppear {
                            Task { await viewModel.loadMore() }
                        }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.lg)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - 时间线分组

    private func timelineSection(date: String, memoirs: [Memoir], isLast: Bool) -> some View {
        VStack(spacing: 0) {
            // 日期标题
            HStack(spacing: DesignTokens.Spacing.sm) {
                Rectangle()
                    .fill(MemoirColors.border)
                    .frame(height: 1)

                Text(formatSectionDate(date))
                    .font(.system(size: DesignTokens.Typography.caption, weight: .medium))
                    .foregroundColor(MemoirColors.textTertiary)
                    .padding(.horizontal, DesignTokens.Spacing.xs)

                Rectangle()
                    .fill(MemoirColors.border)
                    .frame(height: 1)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)

            // 回忆录卡片列表
            ForEach(memoirs) { memoir in
                NavigationLink(destination: MemoirDetailView(memoirId: memoir.id)) {
                    memoirCard(memoir)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 回忆录卡片

    private func memoirCard(_ memoir: Memoir) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // 日期小标
            Text(memoir.date)
                .font(.system(size: DesignTokens.Typography.caption))
                .foregroundColor(MemoirColors.textTertiary)

            // 标题
            Text(memoir.title)
                .font(.system(size: DesignTokens.Typography.headline, weight: .semibold))
                .foregroundColor(MemoirColors.textPrimary)
                .lineLimit(2)

            // 摘要
            if !memoir.content.isEmpty {
                Text(memoir.content)
                    .font(.system(size: DesignTokens.Typography.bodySmall))
                    .foregroundColor(MemoirColors.textSecondary)
                    .lineLimit(3)
                    .lineSpacing(4)
            }

            // 底部标签行
            HStack(spacing: DesignTokens.Spacing.sm) {
                // 心情
                if let mood = memoir.mood, let moodOption = Memoir.moodOptions.first(where: { $0.value == mood }) {
                    Text("\(moodOption.emoji) \(moodOption.label)")
                        .font(.system(size: DesignTokens.Typography.badge))
                        .foregroundColor(MemoirColors.textTertiary)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(MemoirColors.surface)
                        .clipShape(Capsule())
                }

                // 标签
                ForEach(memoir.tags.prefix(3), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: DesignTokens.Typography.badge))
                        .foregroundColor(MemoirColors.primary)
                }

                Spacer()

                // 媒体图标
                if !memoir.media.isEmpty {
                    Image(systemName: "photo")
                        .font(.system(size: 12))
                        .foregroundColor(MemoirColors.textTertiary)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(MemoirColors.card)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
        .shadow(
            color: DesignTokens.Shadow.card.color,
            radius: DesignTokens.Shadow.card.radius,
            y: DesignTokens.Shadow.card.y
        )
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.bottom, DesignTokens.Spacing.sm)
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()

            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(MemoirColors.textTertiary)

            Text("还没有回忆录")
                .font(.system(size: DesignTokens.Typography.title2, weight: .medium))
                .foregroundColor(MemoirColors.textSecondary)

            Text("点击右上角 ✏️ 开始记录你的\n第一段人生故事")
                .font(.system(size: DesignTokens.Typography.body))
                .foregroundColor(MemoirColors.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)

            NavigationLink(destination: MemoirEditorView()) {
                Label("开始记录", systemImage: "square.and.pencil")
                    .frame(maxWidth: 200)
                    .frame(height: 48)
            }
            .buttonStyle(.primaryLarge)
            .padding(.top, DesignTokens.Spacing.sm)

            Spacer()
        }
    }

    // MARK: - 加载中

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("加载回忆录...")
                .font(.system(size: DesignTokens.Typography.body))
                .foregroundColor(MemoirColors.textTertiary)
            Spacer()
        }
    }

    // MARK: - 日期格式化

    private func formatSectionDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }

        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: date)
    }
}

// MARK: - ViewModel

@MainActor
final class MemoirListViewModel: ObservableObject {
    @Published var memoirs: [Memoir] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var hasMore = true
    @Published var errorMessage: String?

    private var currentPage = 1
    private let pageSize = 20

    /// 按日期（年月）分组的回忆录
    var groupedMemoirs: [(key: String, value: [Memoir])] {
        let grouped = Dictionary(grouping: memoirs) { memoir in
            String(memoir.date.prefix(7)) // "YYYY-MM"
        }
        return grouped.sorted { $0.key > $1.key }
    }

    func loadInitial() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        currentPage = 1
        do {
            let response = try await MemoirService.shared.fetchMemoirs(page: 1, limit: pageSize)
            memoirs = response.data
            hasMore = response.pagination.page < response.pagination.totalPages
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }

        currentPage += 1
        do {
            let response = try await MemoirService.shared.fetchMemoirs(page: currentPage, limit: pageSize)
            memoirs.append(contentsOf: response.data)
            hasMore = response.pagination.page < response.pagination.totalPages
        } catch {
            currentPage -= 1
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        currentPage = 1
        do {
            let response = try await MemoirService.shared.fetchMemoirs(page: 1, limit: pageSize)
            withAnimation(.easeInOut(duration: 0.3)) {
                memoirs = response.data
                hasMore = response.pagination.page < response.pagination.totalPages
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    MemoirListView()
}
