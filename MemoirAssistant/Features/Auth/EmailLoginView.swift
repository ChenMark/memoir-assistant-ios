import SwiftUI

// MARK: - 邮箱登录 / 注册页面

struct EmailLoginView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var isRegisterMode = false

    // 登录模式字段
    @State private var account = ""
    @State private var password = ""

    // 注册模式字段
    @State private var registerUsername = ""
    @State private var registerEmail = ""
    @State private var registerPassword = ""
    @State private var registerPhone = ""

    @State private var showPassword = false

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                // 模式切换
                modePicker
                    .padding(.top, DesignTokens.Spacing.xl)

                if isRegisterMode {
                    registerForm
                } else {
                    loginForm
                }

                // 提交按钮
                submitButton
                    .padding(.top, DesignTokens.Spacing.md)

                // 错误提示
                if let error = authService.errorMessage {
                    errorBanner(error)
                }

                Spacer().frame(height: DesignTokens.Spacing.xl)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
        .background(MemoirColors.background.ignoresSafeArea())
        .navigationTitle(isRegisterMode ? "注册" : "邮箱登录")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - 模式切换

    private var modePicker: some View {
        HStack(spacing: 0) {
            modeButton("登录", selected: !isRegisterMode) {
                withAnimation(DesignTokens.Animation.default) {
                    isRegisterMode = false
                    authService.errorMessage = nil
                }
            }
            modeButton("注册", selected: isRegisterMode) {
                withAnimation(DesignTokens.Animation.default) {
                    isRegisterMode = true
                    authService.errorMessage = nil
                }
            }
        }
        .background(MemoirColors.card)
        .cornerRadius(DesignTokens.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(MemoirColors.border, lineWidth: 1)
        )
    }

    private func modeButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: DesignTokens.Typography.button, weight: selected ? .bold : .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundColor(selected ? .white : MemoirColors.textPrimary)
                .background(selected ? MemoirColors.primary : .clear)
                .cornerRadius(DesignTokens.Radius.md)
        }
        .animation(DesignTokens.Animation.default, value: selected)
    }

    // MARK: - 登录表单

    private var loginForm: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            MemoirTextField(
                title: "邮箱 / 用户名 / 手机号",
                text: $account,
                keyboardType: .emailAddress,
                icon: "envelope.fill"
            )

            MemoirSecureField(
                title: "密码",
                text: $password,
                showText: $showPassword
            )
        }
    }

    // MARK: - 注册表单

    private var registerForm: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            MemoirTextField(
                title: "用户名",
                text: $registerUsername,
                icon: "person.fill"
            )

            MemoirTextField(
                title: "邮箱",
                text: $registerEmail,
                keyboardType: .emailAddress,
                icon: "envelope.fill"
            )

            MemoirSecureField(
                title: "密码（8位以上）",
                text: $registerPassword,
                showText: $showPassword
            )

            MemoirTextField(
                title: "手机号（选填）",
                text: $registerPhone,
                keyboardType: .phonePad,
                icon: "phone.fill"
            )
        }
    }

    // MARK: - 提交按钮

    private var submitButton: some View {
        Button {
            Task { await handleSubmit() }
        } label: {
            if authService.isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            } else {
                Text(isRegisterMode ? "注册" : "登录")
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
        }
        .buttonStyle(.primaryLarge)
        .disabled(!isFormValid || authService.isLoading)
        .opacity(isFormValid && !authService.isLoading ? 1 : 0.5)
    }

    // MARK: - 表单验证

    private var isFormValid: Bool {
        if isRegisterMode {
            return registerUsername.count >= 2
                && registerEmail.contains("@")
                && registerPassword.count >= 8
        } else {
            return !account.isEmpty && password.count >= 8
        }
    }

    // MARK: - 提交处理

    private func handleSubmit() async {
        authService.errorMessage = nil
        do {
            if isRegisterMode {
                let phone = registerPhone.isEmpty ? nil : registerPhone
                try await authService.register(
                    username: registerUsername,
                    email: registerEmail,
                    password: registerPassword,
                    phone: phone
                )
            } else {
                try await authService.login(account: account, password: password)
            }
            // 成功后返回
            dismiss()
        } catch let error as APIError {
            authService.errorMessage = error.localizedDescription
        } catch {
            authService.errorMessage = "登录失败，请稍后重试"
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

// MARK: - 自定义输入框组件

/// 文本输入框（适老化：大字号 + 清晰标签）
struct MemoirTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var icon: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(.system(size: DesignTokens.Typography.bodySmall, weight: .medium))
                .foregroundColor(MemoirColors.textPrimary)

            HStack(spacing: DesignTokens.Spacing.sm) {
                if !icon.isEmpty {
                    Image(systemName: icon)
                        .foregroundColor(MemoirColors.textTertiary)
                        .frame(width: 20)
                }
                TextField("", text: $text)
                    .font(.system(size: DesignTokens.Typography.body))
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .sentences)
            }
            .padding(DesignTokens.Spacing.md)
            .background(MemoirColors.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(MemoirColors.border, lineWidth: 1)
            )
        }
    }
}

/// 密码输入框
struct MemoirSecureField: View {
    let title: String
    @Binding var text: String
    @Binding var showText: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(.system(size: DesignTokens.Typography.bodySmall, weight: .medium))
                .foregroundColor(MemoirColors.textPrimary)

            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "lock.fill")
                    .foregroundColor(MemoirColors.textTertiary)
                    .frame(width: 20)

                if showText {
                    TextField("", text: $text)
                        .font(.system(size: DesignTokens.Typography.body))
                        .autocorrectionDisabled()
                } else {
                    SecureField("", text: $text)
                        .font(.system(size: DesignTokens.Typography.body))
                }

                Button {
                    showText.toggle()
                } label: {
                    Image(systemName: showText ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(MemoirColors.textTertiary)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(MemoirColors.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(MemoirColors.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview

#Preview("邮箱登录") {
    NavigationStack {
        EmailLoginView()
            .environmentObject(AuthService.shared)
    }
}

#Preview("注册") {
    NavigationStack {
        EmailLoginView(isRegisterMode: true)
            .environmentObject(AuthService.shared)
    }
}
