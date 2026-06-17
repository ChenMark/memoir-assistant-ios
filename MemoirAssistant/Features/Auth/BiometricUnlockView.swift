import SwiftUI

// MARK: - 生物识别快速解锁

struct BiometricUnlockView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var state: BiometricState = .idle
    @State private var scaleEffect: CGFloat = 1.0

    enum BiometricState {
        case idle, authenticating, success, failed(String)
    }

    var body: some View {
        ZStack {
            MemoirColors.background.ignoresSafeArea()

            VStack(spacing: DesignTokens.Spacing.xl) {
                Spacer()

                // 图标动画
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [MemoirColors.wood, MemoirColors.primaryLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.1), radius: 16, y: 6)

                    Image(systemName: BiometricAuthManager.shared.biometryIcon)
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.white)
                }
                .scaleEffect(scaleEffect)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: scaleEffect
                )

                // 状态文案
                Text(stateText)
                    .font(.system(size: DesignTokens.Typography.title2, weight: .bold))
                    .foregroundColor(MemoirColors.textPrimary)

                Text(subtitleText)
                    .font(.system(size: DesignTokens.Typography.body))
                    .foregroundColor(MemoirColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.xl)

                if case .failed(let msg) = state {
                    Button("重试") {
                        state = .idle
                        Task { await performAuth() }
                    }
                    .buttonStyle(.primary)
                    .padding(.top, DesignTokens.Spacing.md)

                    Button("使用密码登录") {
                        dismiss()
                    }
                    .foregroundColor(MemoirColors.textSecondary)
                    .font(.system(size: DesignTokens.Typography.bodySmall))
                    .padding(.top, DesignTokens.Spacing.sm)
                }

                Spacer()
                Spacer()
            }
            .padding()
        }
        .interactiveDismissDisabled()
        .onAppear {
            scaleEffect = 1.12
            Task { await performAuth() }
        }
    }

    private var stateText: String {
        switch state {
        case .idle, .authenticating: return "验证身份"
        case .success: return "验证成功"
        case .failed: return "验证失败"
        }
    }

    private var subtitleText: String {
        switch state {
        case .idle: return "正在准备..."
        case .authenticating: return "请使用\(BiometricAuthManager.shared.biometryName)"
        case .success: return "欢迎回来"
        case .failed(let msg): return msg
        }
    }

    private func performAuth() async {
        state = .authenticating

        let success = await BiometricAuthManager.shared.authenticate()

        if success {
            state = .success
            // 检查 token 是否仍有效
            if await authService.checkSession() {
                try? await Task.sleep(nanoseconds: 600_000_000)
                dismiss()
            } else {
                state = .failed("登录已过期，请重新登录")
            }
        } else {
            state = .failed("无法识别，请重试或使用密码")
        }
    }
}

#Preview {
    BiometricUnlockView()
        .environmentObject(AuthService.shared)
}
