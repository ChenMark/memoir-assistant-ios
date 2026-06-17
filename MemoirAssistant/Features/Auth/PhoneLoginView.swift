import SwiftUI

// MARK: - 手机号快捷登录页面

struct PhoneLoginView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var phone = ""
    @State private var code = ""
    @State private var countdown = 0
    @State private var isSending = false
    @State private var localError: String?

    private let countdownMax = 60

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xl) {
                // 说明文案
                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text("📱")
                        .font(.system(size: 48))
                        .padding(.bottom, DesignTokens.Spacing.sm)

                    Text("手机号快捷登录")
                        .font(.system(size: DesignTokens.Typography.title2, weight: .bold))
                        .foregroundColor(MemoirColors.textPrimary)

                    Text("新用户将自动注册，无需设置密码")
                        .font(.system(size: DesignTokens.Typography.bodySmall))
                        .foregroundColor(MemoirColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DesignTokens.Spacing.xl)

                // 手机号输入
                MemoirTextField(
                    title: "手机号",
                    text: $phone,
                    keyboardType: .phonePad,
                    icon: "phone.fill"
                )
                .onChange(of: phone) { _, _ in
                    // 限制11位
                    phone = String(phone.filter { $0.isNumber }.prefix(11))
                }

                // 验证码输入
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("验证码")
                        .font(.system(size: DesignTokens.Typography.bodySmall, weight: .medium))
                        .foregroundColor(MemoirColors.textPrimary)

                    HStack(spacing: DesignTokens.Spacing.sm) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "number")
                                .foregroundColor(MemoirColors.textTertiary)
                                .frame(width: 20)
                            TextField("请输入6位验证码", text: $code)
                                .font(.system(size: DesignTokens.Typography.body))
                                .keyboardType(.numberPad)
                                .onChange(of: code) { _, _ in
                                    code = String(code.filter { $0.isNumber }.prefix(6))
                                }
                        }
                        .padding(DesignTokens.Spacing.md)
                        .background(MemoirColors.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                .stroke(MemoirColors.border, lineWidth: 1)
                        )

                        // 发送按钮
                        Button(action: handleSendCode) {
                            if isSending {
                                ProgressView()
                                    .tint(MemoirColors.primary)
                                    .frame(width: 80, height: 48)
                            } else if countdown > 0 {
                                Text("\(countdown)s")
                                    .font(.system(size: DesignTokens.Typography.bodySmall, weight: .medium))
                                    .foregroundColor(MemoirColors.textTertiary)
                                    .frame(width: 80, height: 48)
                            } else {
                                Text("获取验证码")
                                    .font(.system(size: DesignTokens.Typography.bodySmall, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 100, height: 48)
                                    .background(phoneValid ? MemoirColors.primary : MemoirColors.textTertiary)
                                    .cornerRadius(DesignTokens.Radius.sm)
                            }
                        }
                        .disabled(isSending || countdown > 0 || !phoneValid)
                    }
                }

                // 登录按钮
                Button {
                    Task { await handleLogin() }
                } label: {
                    if authService.isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    } else {
                        Text("登录")
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                }
                .buttonStyle(.primaryLarge)
                .disabled(!loginValid || authService.isLoading)
                .opacity(loginValid && !authService.isLoading ? 1 : 0.5)
                .padding(.top, DesignTokens.Spacing.md)

                // 错误提示
                if let msg = localError ?? authService.errorMessage {
                    errorBanner(msg)
                }

                Spacer().frame(height: DesignTokens.Spacing.xl)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .frame(minHeight: UIScreen.main.bounds.height - 200)
        }
        .background(MemoirColors.background.ignoresSafeArea())
        .navigationTitle("手机号登录")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - 验证

    private var phoneValid: Bool {
        phone.count == 11
    }

    private var loginValid: Bool {
        phoneValid && code.count == 6
    }

    // MARK: - 发送验证码

    private func handleSendCode() {
        guard phoneValid else { return }
        isSending = true
        localError = nil

        Task {
            do {
                try await authService.sendSMS(phone: phone)
                startCountdown()
            } catch let error as APIError {
                if case .rateLimited = error {
                    localError = "操作过于频繁，请稍后再试"
                } else {
                    localError = error.localizedDescription
                }
            } catch {
                localError = "发送失败，请检查网络"
            }
            isSending = false
        }
    }

    // MARK: - 倒计时

    private func startCountdown() {
        countdown = countdownMax
        Task {
            while countdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                countdown -= 1
            }
        }
    }

    // MARK: - 登录

    private func handleLogin() async {
        guard loginValid else { return }
        localError = nil
        do {
            try await authService.phoneLogin(phone: phone, code: code)
            dismiss()
        } catch let error as APIError {
            localError = error.localizedDescription
        } catch {
            localError = "登录失败，请稍后重试"
        }
    }

    // MARK: - 错误提示

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(.system(size: DesignTokens.Typography.bodySmall))
        }
        .foregroundColor(MemoirColors.danger)
        .padding(DesignTokens.Spacing.md)
        .background(MemoirColors.danger.opacity(0.08))
        .cornerRadius(DesignTokens.Radius.sm)
    }
}

// MARK: - Preview

#Preview("手机号登录") {
    NavigationStack {
        PhoneLoginView()
            .environmentObject(AuthService.shared)
    }
}
