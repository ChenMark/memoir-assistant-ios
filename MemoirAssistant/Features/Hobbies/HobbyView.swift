import SwiftUI

// MARK: - 爱好管理视图

struct HobbyView: View {
    @State private var selectedCategory: HobbyCategory? = nil
    @State private var hobbies: [Hobby] = []
    @State private var isLoading = true
    @State private var showAddSheet = false
    @State private var editingHobby: Hobby?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分类 Tab
                categoryTabs

                // 内容
                if isLoading && hobbies.isEmpty {
                    loadingView
                } else if hobbies.isEmpty {
                    emptyView
                } else {
                    hobbyList
                }
            }
            .background(MemoirColors.background)
            .navigationTitle("我的爱好")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .foregroundColor(MemoirColors.primary)
                }
            }
            .refreshable { await loadData() }
            .sheet(isPresented: $showAddSheet) {
                HobbyEditorView(hobby: nil, category: selectedCategory) { _ in
                    Task { await loadData() }
                }
            }
            .sheet(item: $editingHobby) { hobby in
                HobbyEditorView(hobby: hobby, category: nil) { _ in
                    Task { await loadData() }
                }
            }
        }
        .task { await loadData() }
        .onChange(of: selectedCategory) { _ in
            Task { await loadData() }
        }
    }

    // MARK: - 分类 Tab

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(label: "全部", icon: "📋", isSelected: selectedCategory == nil)
                    .onTapGesture { selectedCategory = nil }

                ForEach(HobbyCategory.allCases, id: \.self) { cat in
                    categoryChip(label: cat.displayName, icon: cat.icon, isSelected: selectedCategory == cat)
                        .onTapGesture { selectedCategory = cat }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
        .background(MemoirColors.card)
    }

    private func categoryChip(label: String, icon: String, isSelected: Bool) -> some View {
        HStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 14))
            Text(label)
                .font(.system(size: DesignTokens.Typography.bodySmall, weight: isSelected ? .semibold : .regular))
        }
        .foregroundColor(isSelected ? .white : MemoirColors.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? MemoirColors.primary : MemoirColors.primary.opacity(0.06))
        .clipShape(Capsule())
    }

    // MARK: - 列表

    private var hobbyList: some View {
        List {
            ForEach(hobbies) { hobby in
                Button {
                    editingHobby = hobby
                } label: {
                    hobbyRow(hobby)
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                deleteHobbies(at: indexSet)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func hobbyRow(_ hobby: Hobby) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // 左侧图标
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .fill(iconColor(for: hobby.category))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(hobby.category.icon)
                        .font(.system(size: 22))
                )

            // 中间信息
            VStack(alignment: .leading, spacing: 4) {
                Text(hobby.title)
                    .font(.system(size: DesignTokens.Typography.body, weight: .medium))
                    .foregroundColor(MemoirColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let year = hobby.year {
                        Text(year)
                            .font(.system(size: DesignTokens.Typography.caption))
                            .foregroundColor(MemoirColors.textTertiary)
                    }

                    if let rating = hobby.rating {
                        ratingStars(rating, size: 12)
                    }

                    if let desc = hobby.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: DesignTokens.Typography.caption))
                            .foregroundColor(MemoirColors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(MemoirColors.textTertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 评分星星

    private func ratingStars(_ rating: Int, size: CGFloat) -> some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(star <= rating ? Color(red: 0.95, green: 0.7, blue: 0.15) : MemoirColors.border)
            }
        }
    }

    private func iconColor(for category: HobbyCategory) -> Color {
        switch category {
        case .music: return Color(red: 0.85, green: 0.2, blue: 0.3).opacity(0.12)
        case .movie: return Color(red: 0.2, green: 0.4, blue: 0.85).opacity(0.12)
        case .sport: return Color(red: 0.15, green: 0.65, blue: 0.3).opacity(0.12)
        case .custom: return MemoirColors.primary.opacity(0.12)
        }
    }

    // MARK: - 空态 / 加载态

    private var emptyView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()
            Text(selectedCategory?.icon ?? "✨")
                .font(.system(size: 60))
            Text("还没有记录")
                .font(.system(size: DesignTokens.Typography.headline, weight: .semibold))
                .foregroundColor(MemoirColors.textPrimary)
            Text("点击右上角 + 添加你的爱好")
                .font(.system(size: DesignTokens.Typography.bodySmall))
                .foregroundColor(MemoirColors.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 数据

    private func loadData() async {
        do {
            let response = try await HobbyService.shared.fetchHobbies(
                category: selectedCategory,
                page: 1,
                limit: 50
            )
            hobbies = response.data
        } catch {
            hobbies = []
        }
        isLoading = false
    }

    private func deleteHobbies(at indexSet: IndexSet) {
        for index in indexSet {
            let hobby = hobbies[index]
            Task {
                try? await HobbyService.shared.deleteHobby(id: hobby.id)
                hobbies.removeAll { $0.id == hobby.id }
            }
        }
    }
}

// MARK: - 爱好编辑 Sheet

struct HobbyEditorView: View {
    let existingHobby: Hobby?
    let initialCategory: HobbyCategory?
    let onSave: (Hobby) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var category: HobbyCategory = .music
    @State private var title = ""
    @State private var description = ""
    @State private var rating = 0
    @State private var year = ""
    @State private var link = ""
    @State private var tagInput = ""
    @State private var tags: [String] = []

    @State private var isSaving = false
    @State private var errorMessage: String?

    var isEditing: Bool { existingHobby != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                        .font(.system(size: DesignTokens.Typography.body))

                    Picker("分类", selection: $category) {
                        ForEach(HobbyCategory.allCases, id: \.self) { cat in
                            Text("\(cat.icon) \(cat.displayName)").tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("详细") {
                    TextField("描述（可选）", text: $description, axis: .vertical)
                        .font(.system(size: DesignTokens.Typography.body))
                        .lineLimit(3...6)

                    TextField("年份（可选）", text: $year)
                        .font(.system(size: DesignTokens.Typography.body))
                        .keyboardType(.numberPad)

                    TextField("链接（可选）", text: $link)
                        .font(.system(size: DesignTokens.Typography.body))
                        .keyboardType(.URL)
                }

                Section("评分") {
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 28))
                                .foregroundColor(star <= rating ? Color(red: 0.95, green: 0.7, blue: 0.15) : MemoirColors.border)
                                .onTapGesture {
                                    rating = star
                                }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

                Section("标签") {
                    HStack {
                        TextField("添加标签", text: $tagInput)
                            .submitLabel(.done)
                            .onSubmit { addTag() }

                        Button { addTag() } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(MemoirColors.primary)
                        }
                    }

                    if !tags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text(tag)
                                        .font(.system(size: DesignTokens.Typography.caption))
                                    Button {
                                        tags.removeAll { $0 == tag }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(MemoirColors.primary.opacity(0.08))
                                .foregroundColor(MemoirColors.primary)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.system(size: DesignTokens.Typography.caption))
                    }
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            Task { await deleteHobby() }
                        } label: {
                            HStack {
                                Spacer()
                                Text("删除")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MemoirColors.background)
            .navigationTitle(isEditing ? "编辑爱好" : "添加爱好")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "保存" : "添加") {
                        Task { await save() }
                    }
                    .font(.system(size: DesignTokens.Typography.body, weight: .semibold))
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .task {
            if let hobby = existingHobby {
                populate(from: hobby)
            } else if let cat = initialCategory {
                category = cat
            }
        }
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        tagInput = ""
    }

    private func populate(from hobby: Hobby) {
        category = hobby.category
        title = hobby.title
        description = hobby.description ?? ""
        rating = hobby.rating ?? 0
        year = hobby.year ?? ""
        link = hobby.link ?? ""
        tags = hobby.tags
    }

    private func save() async {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "请输入标题"
            return
        }

        isSaving = true
        errorMessage = nil

        let request = HobbyRequest(
            category: category.rawValue,
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.isEmpty ? nil : description,
            rating: rating > 0 ? rating : nil,
            year: year.isEmpty ? nil : year,
            link: link.isEmpty ? nil : link,
            tags: tags.isEmpty ? nil : tags
        )

        do {
            let response: HobbyResponse
            if let hobby = existingHobby {
                response = try await HobbyService.shared.updateHobby(id: hobby.id, request)
            } else {
                response = try await HobbyService.shared.addHobby(request)
            }
            onSave(response.hobby)
            dismiss()
        } catch {
            errorMessage = "保存失败，请重试"
        }
        isSaving = false
    }

    private func deleteHobby() async {
        guard let hobby = existingHobby else { return }
        do {
            try await HobbyService.shared.deleteHobby(id: hobby.id)
            onSave(hobby)
            dismiss()
        } catch {
            errorMessage = "删除失败，请重试"
        }
    }
}

// MARK: - 流式标签布局

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeRows(proposal: proposal, subviews: subviews)
        let height = rows.last?.max(by: { $0.maxY < $1.maxY })?.maxY ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeRows(proposal: proposal, subviews: subviews)
        for row in rows {
            for element in row {
                element.subview.place(
                    at: CGPoint(x: bounds.minX + element.x, y: bounds.minY + element.y),
                    proposal: .unspecified
                )
            }
        }
    }

    private func arrangeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[(subview: LayoutSubview, x: CGFloat, y: CGFloat, maxY: CGFloat)]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[(LayoutSubview, CGFloat, CGFloat, CGFloat)]] = []
        var currentRow: [(LayoutSubview, CGFloat, CGFloat, CGFloat)] = []
        var x: CGFloat = 0
        var y: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !currentRow.isEmpty {
                let maxY = currentRow.map(\.3).max() ?? 0
                y = maxY + spacing
                rows.append(currentRow)
                currentRow = []
                x = 0
            }
            currentRow.append((subview, x, y, y + size.height))
            x += size.width + spacing
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }
}

// MARK: - Preview

#Preview {
    HobbyView()
}
