import SwiftUI

// MARK: - iPad 导航状态（跨视图共享）
// 用于 NavigationSplitView 中 Content → Detail 的导航通信

final class IPadNavigationState: ObservableObject {
    @Published var selectedMemoirId: String?
    @Published var selectedPhotoId: String?
    @Published var selectedFriendId: String?

    func selectMemoir(_ id: String) {
        selectedPhotoId = nil
        selectedFriendId = nil
        selectedMemoirId = id
    }

    func selectPhoto(_ id: String) {
        selectedMemoirId = nil
        selectedFriendId = nil
        selectedPhotoId = id
    }

    func selectFriend(_ id: String) {
        selectedMemoirId = nil
        selectedPhotoId = nil
        selectedFriendId = id
    }

    func clearAll() {
        selectedMemoirId = nil
        selectedPhotoId = nil
        selectedFriendId = nil
    }
}

// MARK: - Environment Key

private struct IPadNavigationStateKey: EnvironmentKey {
    static let defaultValue = IPadNavigationState()
}

extension EnvironmentValues {
    var iPadNavigation: IPadNavigationState {
        get { self[IPadNavigationStateKey.self] }
        set { self[IPadNavigationStateKey.self] = newValue }
    }
}

// MARK: - 侧边栏导航项

enum IPadNavItem: String, CaseIterable, Identifiable {
    case dashboard, memoir, aiInterview = "ai_interview"
    case gallery, friends, hobbies, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "首页"
        case .memoir: return "回忆录"
        case .aiInterview: return "AI 访谈"
        case .gallery: return "画廊"
        case .friends: return "亲友"
        case .hobbies: return "爱好"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .memoir: return "book.fill"
        case .aiInterview: return "bubble.left.and.bubble.right.fill"
        case .gallery: return "photo.on.rectangle.angled"
        case .friends: return "person.2.fill"
        case .hobbies: return "heart.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - iPad 三栏布局

struct IPadContentView: View {
    @State private var selectedNav: IPadNavItem = .dashboard
    @StateObject private var navState = IPadNavigationState()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @EnvironmentObject var accessibilityManager: AccessibilityManager

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarView
        } content: {
            contentView
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .environmentObject(navState)
        .font(.system(size: accessibilityManager.effectiveBodySize))
        .tint(MemoirColors.primary)
        .onAppear {
            SiriShortcutsManager.shared.donateAllShortcuts()
            WidgetDataWriter.shared.refreshIfNeeded()
            PerformanceMonitor.shared.markLaunchComplete()
            PerformanceMonitor.shared.startMemoryMonitoring()
            CrashReportService.shared.setCurrentScreen("iPadContentView")
        }
    }

    // MARK: - 侧边栏

    private var sidebarView: some View {
        List(IPadNavItem.allCases, selection: $selectedNav) { item in
            Label(item.title, systemImage: item.icon)
                .font(.system(size: accessibilityManager.effectiveBodySize, weight: .medium))
                .padding(.vertical, 4)
        }
        .listStyle(.sidebar)
        .navigationTitle("忆往昔")
        .onChange(of: selectedNav) { _, _ in
            navState.clearAll()
        }
    }

    // MARK: - 内容区

    @ViewBuilder
    private var contentView: some View {
        switch selectedNav {
        case .dashboard:
            IPadDashboardView()
        case .memoir:
            IPadMemoirListView()
                .environmentObject(navState)
        case .aiInterview:
            AIInterviewView()
        case .gallery:
            IPadGalleryView()
                .environmentObject(navState)
        case .friends:
            IPadFriendListView()
                .environmentObject(navState)
        case .hobbies:
            NavigationStack { HobbyView().navigationTitle("爱好") }
        case .settings:
            SettingsView()
        }
    }

    // MARK: - 详情区

    @ViewBuilder
    private var detailView: some View {
        Group {
            if let id = navState.selectedMemoirId {
                MemoirDetailView(memoirId: id).id(id)
            } else if let id = navState.selectedPhotoId {
                GalleryDetailView(photoId: id).id(id)
            } else if let id = navState.selectedFriendId {
                FriendDetailView(friendId: id).id(id)
            } else {
                IPadWelcomeView()
            }
        }
    }
}

// MARK: - iPad Memoir 列表（内容栏）

struct IPadMemoirListView: View {
    @EnvironmentObject var navState: IPadNavigationState
    @State private var memoirs: [Memoir] = []
    @State private var isLoading = true
    @State private var currentPage = 1
    @State private var totalPages = 1

    var body: some View {
        NavigationStack {
            List(selection: $navState.selectedMemoirId) {
                if isLoading && memoirs.isEmpty {
                    HStack { Spacer(); ProgressView(); Spacer() }.padding()
                } else if memoirs.isEmpty {
                    Text("还没有回忆录").foregroundColor(MemoirColors.textTertiary).padding()
                } else {
                    ForEach(memoirs) { memoir in
                        IPadMemoirRow(memoir: memoir)
                            .tag(memoir.id)
                            .listRowBackground(MemoirColors.card)
                    }
                    if currentPage < totalPages {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .onAppear { Task { await loadPage(currentPage + 1) } }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(MemoirColors.background)
            .navigationTitle("回忆录")
            .task { await loadPage(1) }
        }
    }

    private func loadPage(_ page: Int) async {
        do {
            let resp = try await MemoirService.shared.fetchMemoirs(page: page, limit: 20)
            if page == 1 { memoirs = resp.data } else { memoirs += resp.data }
            currentPage = page
            totalPages = resp.pagination.totalPages
        } catch {}
        isLoading = false
    }
}

struct IPadMemoirRow: View {
    let memoir: Memoir

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(memoir.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(MemoirColors.textPrimary)
            HStack {
                Text(memoir.date)
                    .font(.system(size: 14))
                    .foregroundColor(MemoirColors.textTertiary)
                if let mood = memoir.mood {
                    Text("·")
                    Text(mood)
                        .font(.system(size: 14))
                        .foregroundColor(MemoirColors.textSecondary)
                }
                Spacer()
                Text(String(memoir.content.prefix(40)) + "...")
                    .font(.system(size: 14))
                    .foregroundColor(MemoirColors.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - iPad 画廊（内容栏）

struct IPadGalleryView: View {
    @EnvironmentObject var navState: IPadNavigationState
    @State private var photos: [GalleryPhoto] = []
    @State private var isLoading = true

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView().padding(40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(photos) { photo in
                            Button {
                                navState.selectPhoto(photo.id)
                            } label: {
                                IPadPhotoThumb(photo: photo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .background(MemoirColors.background)
            .navigationTitle("画廊")
            .task { await loadGallery() }
        }
    }

    private func loadGallery() async {
        do {
            let resp = try await GalleryService.shared.fetchGallery(page: 1, limit: 30)
            photos = resp.data
        } catch {}
        isLoading = false
    }
}

struct IPadPhotoThumb: View {
    let photo: GalleryPhoto
    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Rectangle()
                    .fill(MemoirColors.textTertiary.opacity(0.1))
                    .aspectRatio(1, contentMode: .fill)
                    .overlay {
                        if let img = image {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text(photo.caption.isEmpty ? "无描述" : photo.caption)
                .font(.system(size: 14))
                .foregroundColor(MemoirColors.textPrimary)
                .lineLimit(1)
        }
        .task { await loadThumb() }
    }

    private func loadThumb() async {
        let urlStr = photo.downloadUrl ?? ""
        guard !urlStr.isEmpty, let url = URL(string: urlStr) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            image = UIImage(data: data)
        } catch {}
    }
}

// MARK: - iPad 亲友列表（内容栏）

struct IPadFriendListView: View {
    @EnvironmentObject var navState: IPadNavigationState
    @State private var friends: [Friend] = []
    @State private var selectedCategory: FriendCategory = .family
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List(selection: $navState.selectedFriendId) {
                Picker("分类", selection: $selectedCategory) {
                    ForEach(FriendCategory.allCases, id: \.self) { cat in
                        Text("\(cat.icon) \(cat.displayName)").tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }.padding()
                } else {
                    ForEach(filteredFriends) { friend in
                        IPadFriendRow(friend: friend)
                            .tag(friend.id)
                    }
                    .listRowBackground(MemoirColors.card)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(MemoirColors.background)
            .navigationTitle("亲友")
            .task { await loadFriends() }
            .onChange(of: selectedCategory) { _, _ in }
        }
    }

    private var filteredFriends: [Friend] {
        friends.filter { $0.category == selectedCategory }
    }

    private func loadFriends() async {
        do {
            let resp = try await FriendService.shared.fetchAllFriends()
            friends = resp.data
        } catch {}
        isLoading = false
    }
}

struct IPadFriendRow: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(MemoirColors.primary.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(String(friend.name.prefix(1)))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(MemoirColors.primary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(MemoirColors.textPrimary)
                if let rel = friend.relationship {
                    Text(rel)
                        .font(.system(size: 14))
                        .foregroundColor(MemoirColors.textTertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - iPad 欢迎页

struct IPadWelcomeView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.pages.fill")
                .font(.system(size: 72))
                .foregroundColor(MemoirColors.primary.opacity(0.25))

            Text("忆往昔")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(MemoirColors.textPrimary)

            if let user = authService.currentUser {
                Text("\(user.username)，今天想记录什么回忆？")
                    .font(.system(size: 22))
                    .foregroundColor(MemoirColors.textSecondary)
            }

            Text("从侧边栏选择功能开始记录")
                .font(.system(size: 17))
                .foregroundColor(MemoirColors.textTertiary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MemoirColors.background)
    }
}

// MARK: - iPad Dashboard（双列网格）

struct IPadDashboardView: View {
    @EnvironmentObject var authService: AuthService
    @State private var navigateToWrite = false
    @State private var navigateToAI = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    welcomeCard
                    statsCard
                    quickActionsGrid
                    recentMemoirsGrid
                }
                .padding(20)
            }
            .background(MemoirColors.background)
            .navigationTitle("首页")
            .navigationDestination(isPresented: $navigateToWrite) {
                MemoirEditorView()
            }
            .navigationDestination(isPresented: $navigateToAI) {
                AIInterviewView()
            }
        }
    }

    // MARK: 欢迎卡片

    private var welcomeCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                if let user = authService.currentUser {
                    Text("你好，\(user.username)")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(MemoirColors.textPrimary)
                }
                Text("今天想记录什么回忆？")
                    .font(.system(size: 18))
                    .foregroundColor(MemoirColors.textSecondary)
            }
            Spacer()
            Image(systemName: "book.pages.fill")
                .font(.system(size: 52))
                .foregroundColor(MemoirColors.primary.opacity(0.2))
        }
        .padding(24)
        .background(MemoirColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: DesignTokens.Shadow.card.color, radius: DesignTokens.Shadow.card.radius, y: DesignTokens.Shadow.card.y)
    }

    // MARK: 统计卡片

    private var statsCard: some View {
        IPadStatsCard()
    }

    // MARK: 快捷入口（2×2 网格）

    private var quickActionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            QuickActionCard(icon: "square.and.pencil", title: "写回忆录", color: MemoirColors.primary) {
                navigateToWrite = true
            }
            QuickActionCard(icon: "brain.head.profile", title: "AI 访谈", color: Color(red: 0.4, green: 0.3, blue: 0.7)) {
                navigateToAI = true
            }
            QuickActionCard(icon: "photo.on.rectangle.angled", title: "浏览画廊", color: Color(red: 0.25, green: 0.55, blue: 0.25)) {}
            QuickActionCard(icon: "person.2.fill", title: "管理亲友", color: Color(red: 0.85, green: 0.45, blue: 0.2)) {}
        }
    }

    // MARK: 最近回忆录（双列网格）

    private var recentMemoirsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("最近回忆录")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(MemoirColors.textPrimary)

            RecentMemoirsSection()
        }
    }
}

// MARK: - QuickAction 卡片

struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(MemoirColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(MemoirColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: DesignTokens.Shadow.card.color, radius: DesignTokens.Shadow.card.radius, y: DesignTokens.Shadow.card.y)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - iPad 统计卡片

struct IPadStatsCard: View {
    @State private var memoirCount = 0
    @State private var friendCount = 0
    @State private var photoCount = 0

    var body: some View {
        HStack(spacing: 0) {
            StatBlock(value: "\(memoirCount)", label: "回忆录", icon: "book.closed.fill", color: MemoirColors.primary)
            Divider().frame(height: 44).padding(.horizontal, 16)
            StatBlock(value: "\(photoCount)", label: "照片", icon: "photo.fill", color: .green)
            Divider().frame(height: 44).padding(.horizontal, 16)
            StatBlock(value: "\(friendCount)", label: "亲友", icon: "person.2.fill", color: .orange)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(MemoirColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: DesignTokens.Shadow.card.color, radius: DesignTokens.Shadow.card.radius, y: DesignTokens.Shadow.card.y)
        .task { await loadStats() }
    }

    private func loadStats() async {
        async let m: Void = loadMemoirCount()
        async let p: Void = loadPhotoCount()
        async let f: Void = loadFriendCount()
        _ = await (m, p, f)
    }

    private func loadMemoirCount() async {
        if let resp = try? await MemoirService.shared.fetchMemoirs(page: 1, limit: 1) {
            memoirCount = resp.pagination.total
        }
    }

    private func loadPhotoCount() async {
        if let resp = try? await GalleryService.shared.fetchGallery(page: 1, limit: 1) {
            photoCount = resp.pagination.total
        }
    }

    private func loadFriendCount() async {
        if let resp = try? await FriendService.shared.fetchAllFriends() {
            friendCount = resp.pagination.total
        }
    }
}

struct StatBlock: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(MemoirColors.textPrimary)

            Text(label)
                .font(.system(size: 14))
                .foregroundColor(MemoirColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
