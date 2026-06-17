import SwiftUI

// MARK: - 草稿列表页

struct DraftListView: View {
    @StateObject private var viewModel = DraftListViewModel()
    @State private var draftToDelete: Draft?

    var body: some View {
        ZStack {
            MemoirColors.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.drafts.isEmpty {
                loadingView
            } else if viewModel.drafts.isEmpty && viewModel.localDrafts.isEmpty {
                emptyView
            } else {
                draftList
            }
        }
        .navigationTitle("草稿箱")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadDrafts()
        }
        .refreshable {
            await viewModel.loadDrafts()
        }
    }

    // MARK: - 草稿列表

    private var draftList: some View {
        List {
            // 服务端草稿
            if !viewModel.drafts.isEmpty {
                Section("云端草稿 (\(viewModel.drafts.count))") {
                    ForEach(viewModel.drafts) { draft in
                        NavigationLink(destination: draftEditorView(for: draft)) {
                            draftRow(draft)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                draftToDelete = draft
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            // 本地草稿（离线暂存）
            if !viewModel.localDrafts.isEmpty {
                Section("本地草稿 (\(viewModel.localDrafts.count))") {
                    ForEach(viewModel.localDrafts) { draft in
                        NavigationLink(destination: localDraftEditorView(for: draft)) {
                            localDraftRow(draft)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                DraftManager.shared.removeLocalDraft(id: draft.id)
                                viewModel.localDrafts.removeAll { $0.id == draft.id }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MemoirColors.background)
        .alert("确认删除", isPresented: Binding(
            get: { draftToDelete != nil },
            set: { if !$0 { draftToDelete = nil } }
        )) {
            Button("取消", role: .cancel) {
                draftToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let draft = draftToDelete {
                    Task {
                        await viewModel.deleteDraft(draft)
                        draftToDelete = nil
                    }
                }
            }
        } message: {
            Text("删除后草稿将无法恢复")
        }
    }

    // MARK: - 草稿行

    private func draftRow(_ draft: Draft) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "doc.text")
                .font(.title3)
                .foregroundColor(MemoirColors.primary)
                .frame(width: 40, height: 40)
                .background(MemoirColors.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))

            VStack(alignment: .leading, spacing: 4) {
                Text(draft.title)
                    .font(.system(size: DesignTokens.Typography.body, weight: .medium))
                    .foregroundColor(MemoirColors.textPrimary)
                    .lineLimit(1)

                Text(draft.content.isEmpty ? "暂无内容" : draft.content)
                    .font(.system(size: DesignTokens.Typography.bodySmall))
                    .foregroundColor(MemoirColors.textTertiary)
                    .lineLimit(1)

                Text(formatDate(draft.updatedAt))
                    .font(.system(size: DesignTokens.Typography.caption))
                    .foregroundColor(MemoirColors.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func localDraftRow(_ draft: LocalDraft) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "doc.text")
                .font(.title3)
                .foregroundColor(MemoirColors.warning)
                .frame(width: 40, height: 40)
                .background(MemoirColors.warning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(draft.title)
                        .font(.system(size: DesignTokens.Typography.body, weight: .medium))
                        .foregroundColor(MemoirColors.textPrimary)
                        .lineLimit(1)

                    if draft.serverDraftId == nil {
                        Text("未同步")
                            .font(.system(size: 10))
                            .foregroundColor(MemoirColors.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MemoirColors.warning.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(draft.content.isEmpty ? "暂无内容" : draft.content)
                    .font(.system(size: DesignTokens.Typography.bodySmall))
                    .foregroundColor(MemoirColors.textTertiary)
                    .lineLimit(1)

                Text(formatDateFromSwift(draft.savedAt))
                    .font(.system(size: DesignTokens.Typography.caption))
                    .foregroundColor(MemoirColors.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 跳转编辑

    private func draftEditorView(for draft: Draft) -> some View {
        MemoirEditorViewFromDraft(draft: draft)
    }

    private func localDraftEditorView(for draft: LocalDraft) -> some View {
        MemoirEditorViewFromLocalDraft(localDraft: draft)
    }

    // MARK: - 空/加载

    private var emptyView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(MemoirColors.textTertiary)
            Text("草稿箱是空的")
                .font(.system(size: DesignTokens.Typography.title2, weight: .medium))
                .foregroundColor(MemoirColors.textSecondary)
            Text("新建回忆录时点击「保存草稿」\n即可在此查看")
                .font(.system(size: DesignTokens.Typography.body))
                .foregroundColor(MemoirColors.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    private func formatDate(_ isoStr: String) -> String {
        let fmt = ISO8601DateFormatter()
        guard let date = fmt.date(from: isoStr) else {
            return String(isoStr.prefix(10))
        }
        let out = DateFormatter()
        out.locale = Locale(identifier: "zh_CN")
        out.dateFormat = "MM-dd HH:mm"
        return out.string(from: date)
    }

    private func formatDateFromSwift(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "MM-dd HH:mm"
        return fmt.string(from: date)
    }
}

// MARK: - 从草稿继续编辑

struct MemoirEditorViewFromDraft: View {
    let draft: Draft

    var body: some View {
        MemoirEditorView(editMemoir: Memoir(
            id: draft.id,
            userId: draft.userId,
            title: draft.title,
            content: draft.content,
            tags: draft.tags,
            mood: draft.mood,
            location: nil,
            date: draft.date ?? "",
            media: draft.media,
            isPublished: false,
            createdAt: draft.createdAt,
            updatedAt: draft.updatedAt
        ))
    }
}

struct MemoirEditorViewFromLocalDraft: View {
    let localDraft: LocalDraft

    var body: some View {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        return MemoirEditorView(editMemoir: Memoir(
            id: localDraft.serverDraftId ?? localDraft.id,
            userId: "",
            title: localDraft.title,
            content: localDraft.content,
            tags: localDraft.tags,
            mood: localDraft.mood,
            location: nil,
            date: localDraft.date ?? fmt.string(from: localDraft.savedAt),
            media: localDraft.media,
            isPublished: false,
            createdAt: ISO8601DateFormatter().string(from: localDraft.savedAt),
            updatedAt: ISO8601DateFormatter().string(from: localDraft.savedAt)
        ))
    }
}

// MARK: - ViewModel

@MainActor
final class DraftListViewModel: ObservableObject {
    @Published var drafts: [Draft] = []
    @Published var localDrafts: [LocalDraft] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadDrafts() async {
        isLoading = true
        defer { isLoading = false }

        // 加载服务端草稿
        do {
            let response = try await MemoirService.shared.fetchDrafts()
            drafts = response.data
        } catch {
            errorMessage = error.localizedDescription
        }

        // 加载本地草稿
        localDrafts = DraftManager.shared.localDrafts
    }

    func deleteDraft(_ draft: Draft) async {
        do {
            try await MemoirService.shared.deleteDraft(id: draft.id)
            drafts.removeAll { $0.id == draft.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        DraftListView()
    }
}
