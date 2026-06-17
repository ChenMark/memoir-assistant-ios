import SwiftUI

// MARK: - 主登录页面

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showEmailLogin = false
    @State private var showPhoneLogin = false
    @State private var showRegister = false
    @State private var showBiometricPrompt = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                MemoirColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // 顶部留白
                        Spacer().frame(height: 80)

                        // Logo / 标题区
                        headerSection
                            .padding(.bottom, DesignTokens.Spacing.xl)

                        // 表单输入
                        VStack(spacing: DesignTokens.Spacing.md) {
                            // 邮箱登录按钮（主要）
                            Button {
                                showEmailLogin = true
                            } label: {
                                HStack(spacing: DesignTokens.Spacing.sm) {
                                    Image(systemName: "envelope.fill")
                                    Text("邮箱登录 / 注册")
                                }
                            }
                            .buttonStyle(.primaryLarge)

                            // 手机号快捷登录
                            Button {
                                showPhoneLogin = true
                            } label: {
                                HStack(spacing: DesignTokens.Spacing.sm) {
                                    Image(systemName: "phone.fill")
                                    Text("手机号快捷登录")
                                }
                            }
                            .buttonStyle(.secondary)
                            .buttonStyle(SecondaryButtonStyle(size: .large))

                            // 分隔线
                            HStack(spacing: DesignTokens.Spacing.md) {
                                dividerLine
                                Text("其他方式登录")
                                    .font(.system(size: DesignTokens.Typography.caption))
                                    .foregroundColor(MemoirColors.textTertiary)
                                dividerLine
                            }
                            .padding(.vertical, DesignTokens.Spacing.lg)

                            // OAuth 按钮
                            OAuthLoginButtons()

                            // Face ID 提示
                            if authService.biometricEnabled {
                                biometricButton
                                    .padding(.top, DesignTokens.Spacing.md)
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.lg)

                        // 错误提示
                        if let error = authService.errorMessage {
                            errorBanner(error)
                                .padding(.horizontal, DesignTokens.Spacing.lg)
                                .padding(.top, DesignTokens.Spacing.lg)
                        }

                        // 底部
                        Spacer().frame(height: 60)
                    }
                    .frame(minHeight: UIScreen.main.bounds.height - 100)
                }
            }
            .navigationDestination(isPresented: $showEmailLogin) {
                EmailLoginView()
            }
            .navigationDestination(isPresented: $showPhoneLogin) {
                PhoneLoginView()
            }
            .sheet(isPresented: $showBiometricPrompt) {
                BiometricUnlockView()
            }
            .onAppear {
                // 若已存 token 且开启生物识别，弹出解锁
                if authService.biometricEnabled,
                   KeychainManager.shared.readToken() != nil {
                    showBiometricPrompt = true
                }
            }
        }
        // 适老化：禁掉 NavigationStack 的小字返回按钮，用自定义
        .tint(MemoirColors.primary)
    }

    // MARK: - 子视图

    private var headerSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .fill(
                        LinearGradient(
                            colors: [MemoirColors.wood, MemoirColors.primaryLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 4)

                Text("📖")
                    .font(.system(size: 44))
            }

            Text("忆往昔")
                .font(.system(size: DesignTokens.Typography.title, weight: .bold))
                .foregroundColor(MemoirColors.primary)

            Text("记录人生，分享回忆")
                .font(.system(size: DesignTokens.Typography.body))
                .foregroundColor(MemoirColors.textSecondary)
        }
    }

    private var dividerLine: some View {
        VStack { Divider().background(MemoirColors.border) }
            .frame(maxWidth: .infinity)
    }

    private var biometricButton: some View {
        Button {
            showBiometricPrompt = true
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: BiometricAuthManager.shared.biometryIcon)
                Text(BiometricAuthManager.shared.biometryName)
            }
            .font(.system(size: DesignTokens.Typography.bodySmall))
            .foregroundColor(MemoirColors.primary)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(MemoirColors.danger)
            Text(message)
                .font(.system(size: DesignTokens.Typography.bodySmall))
                .foregroundColor(MemoirColors.danger)
        }
        .padding(DesignTokens.Spacing.md)
        .background(MemoirColors.danger.opacity(0.08))
        .cornerRadius(DesignTokens.Radius.sm)
    }
}

// MARK: - OAuth 按钮组

struct OAuthLoginButtons: View {
    @EnvironmentObject var authService: AuthService
    @State private var showSafari = false
    @State private var safariURL: URL?
    @State private var isLoadingWechat = false
    @State private var isLoadingQQ = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            // 微信
            oauthButton(
                icon: "message.fill",
                label: "微信",
                color: Color(red: 0.027, green: 0.757, blue: 0.376),
                isLoading: isLoadingWechat
            ) {
                Task { await handleOAuthLogin(.wechat) }
            }

            // QQ
            oauthButton(
                icon: "q.circle.fill",
                label: "QQ",
                color: Color(red: 0.071, green: 0.718, blue: 0.961),
                isLoading: isLoadingQQ
            ) {
                Task { await handleOAuthLogin(.qq) }
            }
        }
    }

    private func oauthButton(icon: String, label: String, color: Color, isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                        .background(color)
                        .foregroundColor(.white)
                        .cornerRadius(DesignTokens.Radius.md)
                }
                Text(label)
                    .font(.system(size: DesignTokens.Typography.caption))
                    .foregroundColor(MemoirColors.textSecondary)
            }
        }
        .disabled(isLoading)
    }

    private func handleOAuthLogin(_ provider: OAuthProvider) async {
        let loading = provider == .wechat ? $isLoadingWechat : $isLoadingQQ
        loading.wrappedValue = true
        defer { loading.wrappedValue = false }

        do {
            // 当前后端演示模式：直接模拟登录
            try await authService.demoOAuthLogin(provider: provider)
        } catch {
            authService.errorMessage = "\(provider.name)登录失败"
        }
    }
}

// MARK: - Preview

#Preview("登录页") {
    LoginView()
        .environmentObject(AuthService.shared)
}
