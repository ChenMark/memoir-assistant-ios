import SwiftUI

// MARK: - 回忆录详情页 (阅读模式 + 大字号排版)

struct MemoirDetailView: View {
    let memoirId: String

    @StateObject private var viewModel = MemoirDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            MemoirColors.background.ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
            } else if let memoir = viewModel.memoir {
                readingContent(memoir)
            } else if let error = viewModel.errorMessage {
                errorView(error)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    NavigationLink(destination: MemoirEditorView(editMemoir: viewModel.memoir)) {
                        Label("编辑", systemImage: "pencil")
                    }

                    Button {
                        showShareSheet = true
                    } label: {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(MemoirColors.primary)
                }
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task {
                    await viewModel.delete()
                    dismiss()
                }
            }
        } message: {
            Text("删除后无法恢复，确定要删除「\(viewModel.memoir?.title ?? "")」吗？")
        }
        .sheet(isPresented: $showShareSheet) {
            if let memoir = viewModel.memoir {
                ShareSheet(items: [memoirShareText(memoir)])
            }
        }
        .task {
            await viewModel.load(id: memoirId)
        }
    }

    // MARK: - 阅读内容

    private func readingContent(_ memoir: Memoir) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 头部信息
                headerSection(memoir)

                // 分割线
                Rectangle()
                    .fill(MemoirColors.border)
                    .frame(height: 0.5)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.lg)

                // 正文
                contentSection(memoir)

                // 媒体图片
                if !memoir.media.isEmpty {
                    mediaSection(memoir.media)
                }

                // 底部标签
                footerSection(memoir)

                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - 头部区域

    private func headerSection(_ memoir: Memoir) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // 日期
            Text(formatFullDate(memoir.date))
                .font(.system(size: DesignTokens.Typography.bodySmall))
                .foregroundColor(MemoirColors.textTertiary)

            // 标题
            Text(memoir.title)
                .font(.system(size: DesignTokens.Typography.title, weight: .bold))
                .foregroundColor(MemoirColors.textPrimary)
                .lineSpacing(6)

            // 元信息行
            HStack(spacing: DesignTokens.Spacing.md) {
                // 心情
                if let mood = memoir.mood,
                   let moodOption = Memoir.moodOptions.first(where: { $0.value == mood }) {
                    Label("\(moodOption.emoji) \(moodOption.label)", systemImage: "")
                        .font(.system(size: DesignTokens.Typography.badge))
                        .foregroundColor(MemoirColors.primary)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(MemoirColors.primary.opacity(0.1))
                        .clipShape(Capsule())
                }

                // 地点
                if let location = memoir.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.system(size: DesignTokens.Typography.badge))
                        .foregroundColor(MemoirColors.textSecondary)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.top, DesignTokens.Spacing.md)
    }

    // MARK: - 正文区域

    private func contentSection(_ memoir: Memoir) -> some View {
        Text(memoir.content)
            .font(.system(size: DesignTokens.Typography.body))
            .foregroundColor(MemoirColors.textPrimary)
            .lineSpacing(10)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.lg)
    }

    // MARK: - 媒体区域

    private func mediaSection(_ media: [String]) -> some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Text("📷 相关照片")
                .font(.system(size: DesignTokens.Typography.caption))
                .foregroundColor(MemoirColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignTokens.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(media, id: \.self) { key in
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                            .fill(MemoirColors.surface)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(MemoirColors.textTertiary)
                            }
                            .frame(width: 120, height: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                                    .stroke(MemoirColors.border, lineWidth: 0.5)
                            )
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }
            .padding(.bottom, DesignTokens.Spacing.lg)
        }
    }

    // MARK: - 底部标签

    private func footerSection(_ memoir: Memoir) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if !memoir.tags.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(memoir.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: DesignTokens.Typography.badge))
                            .foregroundColor(MemoirColors.primary)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, 4)
                            .background(MemoirColors.surface)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }

            // 创建/更新时间
            VStack(alignment: .leading, spacing: 2) {
                Text("创建于 \(formatDateTime(memoir.createdAt))")
                    .font(.system(size: DesignTokens.Typography.caption))
                    .foregroundColor(MemoirColors.textTertiary)
                if memoir.updatedAt != memoir.createdAt {
                    Text("更新于 \(formatDateTime(memoir.updatedAt))")
                        .font(.system(size: DesignTokens.Typography.caption))
                        .foregroundColor(MemoirColors.textTertiary)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.top, DesignTokens.Spacing.sm)
        }
    }

    // MARK: - 加载/错误

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("加载中...")
                .font(.system(size: DesignTokens.Typography.body))
                .foregroundColor(MemoirColors.textTertiary)
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(MemoirColors.warning)
            Text(message)
                .font(.system(size: DesignTokens.Typography.body))
                .foregroundColor(MemoirColors.textSecondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                Task { await viewModel.load(id: memoirId) }
            }
            .buttonStyle(.primaryLarge)
            Spacer()
        }
        .padding()
    }

    // MARK: - 格式化

    private func formatFullDate(_ dateStr: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: dateStr) else { return dateStr }
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年 M月 d日 EEEE"
        return fmt.string(from: date)
    }

    private func formatDateTime(_ isoStr: String) -> String {
        let fmt = ISO8601DateFormatter()
        guard let date = fmt.date(from: isoStr) else {
            return String(isoStr.prefix(10))
        }
        let out = DateFormatter()
        out.locale = Locale(identifier: "zh_CN")
        out.dateFormat = "yyyy年 M月 d日 HH:mm"
        return out.string(from: date)
    }

    private func memoirShareText(_ memoir: Memoir) -> String {
        """
        📖 《\(memoir.title)》
        日期：\(memoir.date)
        \(memoir.mood.map { "心情：\($0)" } ?? "")

        \(memoir.content)

        —— 来自「忆往昔」AI 回忆录助手
        """
    }
}

// MARK: - ViewModel

@MainActor
final class MemoirDetailViewModel: ObservableObject {
    @Published var memoir: Memoir?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(id: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            memoir = try await MemoirService.shared.fetchMemoir(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete() async {
        guard let memoir else { return }
        do {
            try await MemoirService.shared.deleteMemoir(id: memoir.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 分享 Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        MemoirDetailView(memoirId: "demo")
    }
}
