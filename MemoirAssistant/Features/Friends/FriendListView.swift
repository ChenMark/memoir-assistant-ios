import SwiftUI

// MARK: - 亲友列表视图（三段式：家人 / 同学 / 朋友）

struct FriendListView: View {
    @State private var selectedCategory: FriendCategory = .family
    @State private var friends: [Friend] = []
    @State private var isLoading = true
    @State private var currentPage = 1
    @State private var hasMore = true
    @State private var showAddSheet = false
    @State private var editingFriend: Friend?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分段选择器
                categoryPicker

                // 内容区
                if isLoading && friends.isEmpty {
                    loadingView
                } else if friends.isEmpty {
                    emptyView
                } else {
                    friendList
                }
            }
            .background(MemoirColors.background)
            .navigationTitle("亲友")
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

                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedCategory == .family && !friends.isEmpty {
                        NavigationLink(destination: FamilyTreeView()) {
                            Image(systemName: "flowchart")
                        }
                        .foregroundColor(MemoirColors.primary)
                    }
                }
            }
            .refreshable { await loadData(reset: true) }
            .sheet(isPresented: $showAddSheet) {
                FriendDetailView(friend: nil, category: selectedCategory) { _ in
                    Task { await loadData(reset: true) }
                }
            }
            .sheet(item: $editingFriend) { friend in
                FriendDetailView(friend: friend, category: friend.category) { _ in
                    Task { await loadData(reset: true) }
                }
            }
        }
        .task { await loadData(reset: true) }
        .onChange(of: selectedCategory) { _ in
            Task { await loadData(reset: true) }
        }
    }

    // MARK: - 分段选择器

    private var categoryPicker: some View {
        HStack(spacing: 0) {
            ForEach(FriendCategory.allCases, id: \.self) { cat in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = cat
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text("\(cat.icon) \(cat.displayName)")
                            .font(.system(size: DesignTokens.Typography.bodySmall, weight: selectedCategory == cat ? .semibold : .regular))
                            .foregroundColor(selectedCategory == cat ? MemoirColors.primary : MemoirColors.textSecondary)
                            .padding(.vertical, 14)

                        Rectangle()
                            .fill(selectedCategory == cat ? MemoirColors.primary : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .background(MemoirColors.card)
    }

    // MARK: - 好友列表

    private var friendList: some View {
        List {
            ForEach(friends) { friend in
                Button {
                    editingFriend = friend
                } label: {
                    friendRow(friend)
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                deleteFriends(at: indexSet)
            }

            // 分页加载
            if hasMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
                .listRowBackground(Color.clear)
                .task {
                    await loadData(reset: false)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - 单行

    private func friendRow(_ friend: Friend) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // 头像
            avatarView(for: friend)
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().stroke(MemoirColors.border, lineWidth: 1))

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.system(size: DesignTokens.Typography.body, weight: .medium))
                    .foregroundColor(MemoirColors.textPrimary)

                if let rel = friend.relationship, selectedCategory == .family {
                    Text(rel)
                        .font(.system(size: DesignTokens.Typography.caption))
                        .foregroundColor(MemoirColors.textTertiary)
                } else if let desc = subtitle(for: friend) {
                    Text(desc)
                        .font(.system(size: DesignTokens.Typography.caption))
                        .foregroundColor(MemoirColors.textTertiary)
                }
            }

            Spacer()

            // 标签
            if !friend.tags.isEmpty {
                ForEach(friend.tags.prefix(2), id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 11))
                        .foregroundColor(MemoirColors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(MemoirColors.primary.opacity(0.08))
                        .clipShape(Capsule())
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(MemoirColors.textTertiary)
        }
        .padding(.vertical, 4)
    }

    private func avatarView(for friend: Friend) -> some View {
        Group {
            if let avatar = friend.avatar, !avatar.isEmpty {
                AsyncImage(url: URL(string: avatar)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarPlaceholder(name: friend.name)
                    }
                }
            } else {
                avatarPlaceholder(name: friend.name)
            }
        }
    }

    private func avatarPlaceholder(name: String) -> some View {
        ZStack {
            MemoirColors.primary.opacity(0.1)
            Text(String(name.prefix(1)))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(MemoirColors.primary)
        }
    }

    private func subtitle(for friend: Friend) -> String? {
        switch friend.category {
        case .classMate:
            return [friend.school, friend.classInfo].compactMap { $0 }.joined(separator: " · ")
        case .friend:
            return friend.metAt
        case .family:
            return nil
        }
    }

    // MARK: - 空态 / 加载态

    private var emptyView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()
            Text(selectedCategory.icon)
                .font(.system(size: 60))
            Text("还没有\(selectedCategory.displayName)")
                .font(.system(size: DesignTokens.Typography.headline, weight: .semibold))
                .foregroundColor(MemoirColors.textPrimary)
            Text("点击右上角 + 开始添加")
                .font(.system(size: DesignTokens.Typography.bodySmall))
                .foregroundColor(MemoirColors.textTertiary)
            Button {
                showAddSheet = true
            } label: {
                Text("添加\(selectedCategory.displayName)")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.primary)
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

    // MARK: - 数据加载

    private func loadData(reset: Bool) async {
        if reset {
            currentPage = 1
            hasMore = true
        }

        guard hasMore else { return }

        do {
            let response = try await FriendService.shared.fetchFriends(
                category: selectedCategory,
                page: currentPage,
                limit: 20
            )

            if reset {
                friends = response.data
            } else {
                friends.append(contentsOf: response.data)
            }
            currentPage += 1
            hasMore = response.data.count >= 20
        } catch {
            // 静默处理
        }
        isLoading = false
    }

    private func deleteFriends(at indexSet: IndexSet) {
        for index in indexSet {
            let friend = friends[index]
            Task {
                try? await FriendService.shared.deleteFriend(id: friend.id)
                friends.removeAll { $0.id == friend.id }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FriendListView()
}
