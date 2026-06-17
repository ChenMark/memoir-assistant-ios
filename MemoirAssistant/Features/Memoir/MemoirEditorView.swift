import SwiftUI

// MARK: - 新建/编辑回忆录

struct MemoirEditorView: View {
    var editMemoir: Memoir? = nil

    @StateObject private var viewModel = MemoirEditorViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    enum Field {
        case title, content
    }

    var body: some View {
        ZStack {
            MemoirColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // 标题
                    titleField

                    // 日期选择
                    datePicker

                    // 正文
                    contentField

                    // 心情选择
                    moodPicker

                    // 地点输入
                    locationField

                    // 标签选择
                    tagPicker

                    // 底部按钮
                    actionButtons
                }
                .padding(DesignTokens.Spacing.lg)
            }
        }
        .navigationTitle(editMemoir != nil ? "编辑回忆录" : "新建回忆录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") {
                    viewModel.cancelAutoSave()
                    dismiss()
                }
                .foregroundColor(MemoirColors.textSecondary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存为草稿") {
                    Task {
                        await viewModel.saveAsDraft()
                        dismiss()
                    }
                }
                .font(.system(size: DesignTokens.Typography.bodySmall, weight: .medium))
                .foregroundColor(MemoirColors.primary)
            }
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                    .font(.system(size: DesignTokens.Typography.bodySmall, weight: .medium))
                }
            }
        }
        .alert("保存失败", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .task {
            if let memoir = editMemoir {
                viewModel.loadFromMemoir(memoir)
            }
            viewModel.startAutoSave()
        }
        .onDisappear {
            viewModel.cancelAutoSave()
        }
    }

    // MARK: - 标题

    private var titleField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("标题")
                .font(.system(size: DesignTokens.Typography.caption, weight: .medium))
                .foregroundColor(MemoirColors.textTertiary)

            TextField("给回忆取个名字...", text: $viewModel.title)
                .font(.system(size: DesignTokens.Typography.title2, weight: .semibold))
                .foregroundColor(MemoirColors.textPrimary)
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit { focusedField = .content }
        }
    }

    // MARK: - 日期选择

    private var datePicker: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("回忆日期")
                .font(.system(size: DesignTokens.Typography.caption, weight: .medium))
                .foregroundColor(MemoirColors.textTertiary)

            DatePicker(
                "",
                selection: Binding(
                    get: { viewModel.selectedDate },
                    set: { viewModel.selectedDate = $0 }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "zh_CN"))
        }
    }

    // MARK: - 正文

    private var contentField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("内容")
                .font(.system(size: DesignTokens.Typography.caption, weight: .medium))
                .foregroundColor(MemoirColors.textTertiary)

            ZStack(alignment: .topLeading) {
                if viewModel.content.isEmpty {
                    Text("写下你的回忆...")
                        .font(.system(size: DesignTokens.Typography.body))
                        .foregroundColor(MemoirColors.textTertiary)
                        .padding(.top, 10)
                        .padding(.leading, 4)
                }

                TextEditor(text: $viewModel.content)
                    .font(.system(size: DesignTokens.Typography.body))
                    .foregroundColor(MemoirColors.textPrimary)
                    .focused($focusedField, equals: .content)
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
            }
            .padding(DesignTokens.Spacing.md)
            .background(MemoirColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(MemoirColors.border, lineWidth: 0.5)
            )
        }
    }

    // MARK: - 心情选择

    private var moodPicker: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("心情")
                .font(.system(size: DesignTokens.Typography.caption, weight: .medium))
                .foregroundColor(MemoirColors.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(Memoir.moodOptions, id: \.value) { option in
                        Button {
                            viewModel.mood = viewModel.mood == option.value ? nil : option.value
                        } label: {
                            VStack(spacing: 4) {
                                Text(option.emoji)
                                    .font(.title2)
                                Text(option.label)
                                    .font(.system(size: 11))
                            }
                            .frame(width: 56, height: 64)
                            .background(
                                viewModel.mood == option.value
                                    ? MemoirColors.primary.opacity(0.15)
                                    : MemoirColors.surface
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                                    .stroke(
                                        viewModel.mood == option.value
                                            ? MemoirColors.primary
                                            : MemoirColors.border,
                                        lineWidth: viewModel.mood == option.value ? 1.5 : 0.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 地点

    private var locationField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("地点")
                .font(.system(size: DesignTokens.Typography.caption, weight: .medium))
                .foregroundColor(MemoirColors.textTertiary)

            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(MemoirColors.textTertiary)
                TextField("例如：北京、家乡的小河边", text: $viewModel.location)
                    .font(.system(size: DesignTokens.Typography.body))
            }
            .padding(DesignTokens.Spacing.md)
            .background(MemoirColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(MemoirColors.border, lineWidth: 0.5)
            )
        }
    }

    // MARK: - 标签选择

    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("标签")
                .font(.system(size: DesignTokens.Typography.caption, weight: .medium))
                .foregroundColor(MemoirColors.textTertiary)

            // 自定义标签输入
            HStack {
                TextField("添加自定义标签...", text: $viewModel.tagInput)
                    .font(.system(size: DesignTokens.Typography.bodySmall))
                    .onSubmit {
                        viewModel.addCustomTag()
                    }

                if !viewModel.tagInput.isEmpty {
                    Button {
                        viewModel.addCustomTag()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(MemoirColors.primary)
                    }
                }
            }
            .padding(DesignTokens.Spacing.sm)
            .background(MemoirColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(MemoirColors.border, lineWidth: 0.5)
            )

            // 已选标签
            if !viewModel.selectedTags.isEmpty {
                FlowLayout(spacing: DesignTokens.Spacing.xs) {
                    ForEach(viewModel.selectedTags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                                .font(.system(size: DesignTokens.Typography.badge))
                                .foregroundColor(.white)
                            Button {
                                viewModel.selectedTags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, 6)
                        .background(MemoirColors.primary)
                        .clipShape(Capsule())
                    }
                }
            }

            // 推荐标签
            Text("推荐标签")
                .font(.system(size: DesignTokens.Typography.badge))
                .foregroundColor(MemoirColors.textTertiary)
                .padding(.top, 4)

            FlowLayout(spacing: DesignTokens.Spacing.xs) {
                ForEach(Memoir.suggestedTags, id: \.self) { tag in
                    if !viewModel.selectedTags.contains(tag) {
                        Button {
                            viewModel.selectedTags.append(tag)
                        } label: {
                            Text("#\(tag)")
                                .font(.system(size: DesignTokens.Typography.badge))
                                .foregroundColor(MemoirColors.primary)
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                                .padding(.vertical, 6)
                                .background(MemoirColors.primary.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 操作按钮

    private var actionButtons: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Button {
                Task {
                    let success = await viewModel.publish()
                    if success { dismiss() }
                }
            } label: {
                HStack {
                    if viewModel.isPublishing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.isPublishing ? "发布中..." : "发布回忆录")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
            .buttonStyle(.primaryLarge)
            .disabled(viewModel.title.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isPublishing)

            Button {
                Task {
                    await viewModel.saveAsDraft()
                    dismiss()
                }
            } label: {
                Text("保存草稿")
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(MemoirColors.surface)
            .foregroundColor(MemoirColors.primary)
        }
        .padding(.top, DesignTokens.Spacing.md)
    }
}

// MARK: - ViewModel

@MainActor
final class MemoirEditorViewModel: ObservableObject {
    @Published var title = ""
    @Published var content = ""
    @Published var selectedDate = Date()
    @Published var mood: String?
    @Published var location = ""
    @Published var selectedTags: [String] = []
    @Published var tagInput = ""
    @Published var isPublishing = false
    @Published var showError = false
    @Published var errorMessage: String?

    private var editId: String?
    private var localDraftId: String?
    private let draftManager = DraftManager.shared
    private let memoirService = MemoirService.shared

    // MARK: - 加载编辑数据

    func loadFromMemoir(_ memoir: Memoir) {
        editId = memoir.id
        title = memoir.title
        content = memoir.content
        selectedTags = memoir.tags
        mood = memoir.mood
        location = memoir.location ?? ""

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        if let date = fmt.date(from: memoir.date) {
            selectedDate = date
        }
    }

    // MARK: - 自动保存

    func startAutoSave() {
        localDraftId = UUID().uuidString
    }

    func cancelAutoSave() {
        draftManager.cancelAutoSave()
    }

    private func saveLocallyForHistory() {
        let draft = draftManager.saveLocalDraft(
            id: localDraftId,
            title: title.isEmpty ? "未命名回忆录" : title,
            content: content,
            tags: selectedTags,
            mood: mood,
            date: dateString(),
            media: []
        )
        // 同步到服务端草稿
        draftManager.scheduleAutoSave(draft: draft)
    }

    // MARK: - 发布

    func publish() async -> Bool {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }

        isPublishing = true
        defer { isPublishing = false }

        do {
            let request = CreateMemoirRequest(
                title: title.trimmingCharacters(in: .whitespaces),
                content: content,
                date: dateString(),
                tags: selectedTags,
                mood: mood,
                location: location.isEmpty ? nil : location.trimmingCharacters(in: .whitespaces),
                media: nil,
                isPublished: true
            )

            if let id = editId {
                let updateReq = UpdateMemoirRequest(
                    title: request.title,
                    content: request.content,
                    date: request.date,
                    tags: request.tags,
                    mood: request.mood,
                    location: request.location,
                    media: request.media,
                    isPublished: true
                )
                _ = try await memoirService.updateMemoir(id: id, updateReq)
            } else {
                _ = try await memoirService.createMemoir(request)
            }

            // 清理本地草稿
            if let draftId = localDraftId {
                draftManager.removeLocalDraft(id: draftId)
            }

            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    // MARK: - 保存草稿

    func saveAsDraft() async {
        // 先保存到本地
        saveLocallyForHistory()
    }

    // MARK: - 标签

    func addCustomTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !selectedTags.contains(tag) else { return }
        selectedTags.append(tag)
        tagInput = ""
    }

    // MARK: - 工具

    private func dateString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: selectedDate)
    }
}

// MARK: - FlowLayout (标签流式布局)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(in: bounds.width, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: .init(frame.size)
            )
        }
    }

    private func arrangeSubviews(in width: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }

        let totalHeight = y + maxHeight
        return (CGSize(width: width, height: totalHeight), frames)
    }
}

#Preview {
    NavigationStack {
        MemoirEditorView()
    }
}
