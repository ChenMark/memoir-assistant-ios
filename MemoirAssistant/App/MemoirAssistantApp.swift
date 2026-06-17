import SwiftUI

@main
struct MemoirAssistantApp: App {
    @StateObject private var authService = AuthService.shared
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView()
                } else if authService.isAuthenticated {
                    ContentView()
                        .environmentObject(authService)
                } else {
                    LoginView()
                        .environmentObject(authService)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
                authService.logout()
            }
            .dynamicTypeSize(.medium ... .xxxLarge)
            .tint(MemoirColors.primary)
        }
    }
}

// MARK: - 主内容 Tab 视图

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(0)

            MemoirListView()
                .tabItem {
                    Label("回忆录", systemImage: "book.fill")
                }
                .tag(1)

            GalleryView()
                .tabItem {
                    Label("画廊", systemImage: "photo.on.rectangle.angled")
                }
                .tag(2)

            FriendsView()
                .tabItem {
                    Label("亲友", systemImage: "person.2.fill")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .font(.system(size: DesignTokens.Typography.tab))
    }
}

// MARK: - 占位视图

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            Text("首页仪表盘 — M3 实现")
                .font(.system(size: DesignTokens.Typography.title2, weight: .bold))
                .foregroundColor(MemoirColors.textSecondary)
                .navigationTitle("忆往昔")
        }
    }
}

struct MemoirListView: View {
    var body: some View {
        NavigationStack {
            Text("回忆录列表 — M3 实现")
                .font(.system(size: DesignTokens.Typography.title2, weight: .bold))
                .foregroundColor(MemoirColors.textSecondary)
                .navigationTitle("回忆录")
        }
    }
}

struct GalleryView: View {
    var body: some View {
        NavigationStack {
            Text("画廊 — M4 实现")
                .font(.system(size: DesignTokens.Typography.title2, weight: .bold))
                .foregroundColor(MemoirColors.textSecondary)
                .navigationTitle("画廊")
        }
    }
}

struct FriendsView: View {
    var body: some View {
        NavigationStack {
            Text("亲友管理 — M5 实现")
                .font(.system(size: DesignTokens.Typography.title2, weight: .bold))
                .foregroundColor(MemoirColors.textSecondary)
                .navigationTitle("亲友")
        }
    }
}

// MARK: - 设置页

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationStack {
            List {
                // 账户
                Section {
                    NavigationLink(destination: ProfileView()) {
                        Label("个人资料", systemImage: "person.circle.fill")
                    }

                    NavigationLink(destination: AccountSettingsView()) {
                        Label("账户设置", systemImage: "gearshape.2.fill")
                    }
                } header: {
                    Text("账户")
                }

                // 当前用户
                if let user = authService.currentUser {
                    Section("当前登录") {
                        HStack {
                            Text("用户名")
                            Spacer()
                            Text(user.username)
                                .foregroundColor(MemoirColors.textSecondary)
                        }
                        HStack {
                            Text("邮箱")
                            Spacer()
                            Text(user.email ?? "--")
                                .foregroundColor(MemoirColors.textSecondary)
                        }
                    }
                }

                // 登出
                Section {
                    Button(role: .destructive) {
                        authService.logout()
                    } label: {
                        HStack {
                            Spacer()
                            Text("退出登录")
                                .font(.system(size: DesignTokens.Typography.body, weight: .medium))
                            Spacer()
                        }
                    }
                }

                // 关于
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.1.0 (M2)")
                            .foregroundColor(MemoirColors.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MemoirColors.background)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - 引导页

struct OnboardingView: View {
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    private let pages: [(emoji: String, title: String, desc: String)] = [
        ("📖", "欢迎来到忆往昔", "AI 助手帮你记录珍贵的人生回忆"),
        ("🎙️", "轻松讲述", "语音输入，AI 整理成文\n就像和朋友聊天一样简单"),
        ("📸", "珍藏瞬间", "拍照或上传照片，图文并茂记录故事"),
        ("👨‍👩‍👧‍👦", "家族记忆", "记录亲友关系，构建你的家族树"),
    ]

    var body: some View {
        ZStack {
            MemoirColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // 底部按钮
                VStack(spacing: DesignTokens.Spacing.md) {
                    Button {
                        hasCompletedOnboarding = true
                    } label: {
                        Text(currentPage < pages.count - 1 ? "下一步" : "开始记录回忆")
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.primaryLarge)
                    .padding(.horizontal, DesignTokens.Spacing.lg)

                    if currentPage < pages.count - 1 {
                        Button("跳过") {
                            hasCompletedOnboarding = true
                        }
                        .foregroundColor(MemoirColors.textTertiary)
                        .font(.system(size: DesignTokens.Typography.bodySmall))
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }

    private func pageView(_ page: (String, String, String)) -> some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            Text(page.0)
                .font(.system(size: 80))

            Text(page.1)
                .font(.system(size: DesignTokens.Typography.title, weight: .bold))
                .foregroundColor(MemoirColors.primary)

            Text(page.2)
                .font(.system(size: DesignTokens.Typography.body))
                .foregroundColor(MemoirColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .lineSpacing(8)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
}
