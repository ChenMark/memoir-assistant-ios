import SwiftUI

// MARK: - 亲友详情 / 编辑视图

struct FriendDetailView: View {
    let existingFriend: Friend?
    let initialCategory: FriendCategory
    let onSave: (Friend) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: FriendCategory
    @State private var avatar = ""
    @State private var relationship = ""
    @State private var generation = 0
    @State private var parentId = ""
    @State private var spouseId = ""
    @State private var school = ""
    @State private var classInfo = ""
    @State private var graduationYear = ""
    @State private var metAt = ""
    @State private var metYear = ""
    @State private var tagInput = ""
    @State private var tags: [String] = []

    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    init(friend: Friend?, category: FriendCategory, onSave: @escaping (Friend) -> Void) {
        self.existingFriend = friend
        self.initialCategory = category
        self.onSave = onSave
        _category = State(initialValue: category)
    }

    var isEditing: Bool { existingFriend != nil }

    var body: some View {
        NavigationStack {
            Form {
                // 基本信息
                Section("基本信息") {
                    TextField("姓名", text: $name)
                        .font(.system(size: DesignTokens.Typography.body))

                    Picker("分类", selection: $category) {
                        ForEach(FriendCategory.allCases, id: \.self) { cat in
                            Text("\(cat.icon) \(cat.displayName)").tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // 按分类显示不同字段
                switch category {
                case .family:
                    familySection
                case .classMate:
                    classmateSection
                case .friend:
                    friendSection
                }

                // 标签
                Section("标签") {
                    HStack {
                        TextField("添加标签", text: $tagInput)
                            .font(.system(size: DesignTokens.Typography.body))
                            .submitLabel(.done)
                            .onSubmit { addTag() }

                        Button {
                            addTag()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(MemoirColors.primary)
                        }
                    }

                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
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
                }

                // 错误提示
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.system(size: DesignTokens.Typography.caption))
                    }
                }

                // 删除
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("删除亲友")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MemoirColors.background)
            .navigationTitle(isEditing ? "编辑亲友" : "添加\(initialCategory.displayName)")
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
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("删除", role: .destructive) { Task { await deleteFriend() } }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后无法恢复，确定要移除「\(name)」吗？")
            }
        }
        .task {
            if let friend = existingFriend {
                populate(from: friend)
            }
        }
    }

    // MARK: - 家人字段

    private var familySection: some View {
        Section("家族信息") {
            TextField("关系（如：父亲、配偶）", text: $relationship)
                .font(.system(size: DesignTokens.Typography.body))

            Picker("辈分", selection: $generation) {
                ForEach(Generation.selectableOptions, id: \.value) { opt in
                    Text(opt.label).tag(opt.value)
                }
            }
            .pickerStyle(.menu)

            TextField("父节点ID（留空为顶级）", text: $parentId)
                .font(.system(size: DesignTokens.Typography.bodySmall))

            TextField("配偶ID（可选）", text: $spouseId)
                .font(.system(size: DesignTokens.Typography.bodySmall))
        }
    }

    // MARK: - 同学字段

    private var classmateSection: some View {
        Section("同学录信息") {
            TextField("学校", text: $school)
                .font(.system(size: DesignTokens.Typography.body))

            TextField("班级", text: $classInfo)
                .font(.system(size: DesignTokens.Typography.body))

            TextField("毕业年份", text: $graduationYear)
                .font(.system(size: DesignTokens.Typography.body))
                .keyboardType(.numberPad)
        }
    }

    // MARK: - 朋友字段

    private var friendSection: some View {
        Section("相识信息") {
            TextField("相识地点", text: $metAt)
                .font(.system(size: DesignTokens.Typography.body))

            TextField("相识年份", text: $metYear)
                .font(.system(size: DesignTokens.Typography.body))
                .keyboardType(.numberPad)
        }
    }

    // MARK: - Actions

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        tagInput = ""
    }

    private func populate(from friend: Friend) {
        name = friend.name
        category = friend.category
        avatar = friend.avatar ?? ""
        relationship = friend.relationship ?? ""
        generation = friend.generation ?? 0
        parentId = friend.parentId ?? ""
        spouseId = friend.spouseId ?? ""
        school = friend.school ?? ""
        classInfo = friend.classInfo ?? ""
        graduationYear = friend.graduationYear ?? ""
        metAt = friend.metAt ?? ""
        metYear = friend.metYear ?? ""
        tags = friend.tags
    }

    private func save() async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "请输入姓名"
            return
        }

        isSaving = true
        errorMessage = nil

        let request = FriendRequest(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category.rawValue,
            avatar: avatar.isEmpty ? nil : avatar,
            relationship: relationship.isEmpty ? nil : relationship,
            generation: generation,
            parentId: parentId.isEmpty ? nil : parentId,
            spouseId: spouseId.isEmpty ? nil : spouseId,
            school: school.isEmpty ? nil : school,
            classInfo: classInfo.isEmpty ? nil : classInfo,
            graduationYear: graduationYear.isEmpty ? nil : graduationYear,
            metAt: metAt.isEmpty ? nil : metAt,
            metYear: metYear.isEmpty ? nil : metYear,
            tags: tags.isEmpty ? nil : tags
        )

        do {
            let response: FriendResponse
            if let friend = existingFriend {
                response = try await FriendService.shared.updateFriend(id: friend.id, request)
            } else {
                response = try await FriendService.shared.addFriend(request)
            }
            onSave(response.friend)
            dismiss()
        } catch {
            errorMessage = "保存失败，请重试"
        }
        isSaving = false
    }

    private func deleteFriend() async {
        guard let friend = existingFriend else { return }
        do {
            try await FriendService.shared.deleteFriend(id: friend.id)
            onSave(friend)
            dismiss()
        } catch {
            errorMessage = "删除失败，请重试"
        }
    }
}

// MARK: - Preview

#Preview {
    FriendDetailView(friend: nil, category: .family) { _ in }
}
