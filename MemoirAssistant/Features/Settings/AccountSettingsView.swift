import SwiftUI

// MARK: - 账户设置页

struct AccountSettingsView: View {
    @EnvironmentObject var authService: AuthService

    // 密码修改
    @State private var showChangePassword = false
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showOldPassword = false
    @State private var showNewPassword = false

    // 注销
    @State private var showDeleteConfirmation = false
    @State private var deletePassword = ""
    @State private var showDeletePassword = false

    @State private var localError: String?
    @State private var successMessage: String?

    var body: some View {
        List {
            // MARK: 安全
            Section("安全") {
                // 生物识别开关
                if BiometricAuthManager.shared.isAvailable {
                    HStack {
                        Image(systemName: BiometricAuthManager.shared.biometryIcon)
                            .foregroundColor(MemoirColors.primary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                            Text(BiometricAuthManager.shared.biometryName)
                                .font(.system(size: DesignTokens.Typography.body))
                                .foregroundColor(MemoirColors.textPrimary)
                            Text("快速安全地登录")
                                .font(.system(size: DesignTokens.Typography.caption))
                                .foregroundColor(MemoirColors.textTertiary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { authService.biometricEnabled },
                            set: { authService.biometricEnabled = $0 }
                        ))
                        .tint(MemoirColors.primary)
                        .labelsHidden()
                    }
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                }

                // 修改密码
                Button {
                    showChangePassword.toggle()
                } label: {
                    HStack {
                        Image(systemName: "lock.rotation")
                            .foregroundColor(MemoirColors.primary)
                            .frame(width: 28)
                        Text("修改密码")
                            .font(.system(size: DesignTokens.Typography.body))
                            .foregroundColor(MemoirColors.textPrimary)
                        Spacer()
                        Image(systemName: showChangePassword ? "chevron.up" : "chevron.down")
                            .foregroundColor(MemoirColors.textTertiary)
                            .font(.system(size: DesignTokens.Typography.caption))
                    }
                }

                if showChangePassword {
                    changePasswordForm
                }
            }

            // MARK: 危险操作
            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .frame(width: 28)
                        Text("注销账号")
                            .font(.system(size: DesignTokens.Typography.body))
                    }
                }
            } header: {
                Text("危险操作")
            } footer: {
                Text("注销后所有数据将被永久删除，无法恢复")
            }

            // 提示信息
            if let error = localError {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                            .font(.system(size: DesignTokens.Typography.bodySmall))
                    }
                    .foregroundColor(MemoirColors.danger)
                }
            }

            if let msg = successMessage {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(msg)
                            .font(.system(size: DesignTokens.Typography.bodySmall))
                    }
                    .foregroundColor(MemoirColors.success)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MemoirColors.background)
        .navigationTitle("账户设置")
        .navigationBarTitleDisplayMode(.large)
        // 注销确认弹窗
        .alert("确认注销", isPresented: $showDeleteConfirmation) {
            SecureField("输入密码确认", text: $deletePassword)
                .font(.system(size: DesignTokens.Typography.body))

            Button("取消", role: .cancel) {}
            Button("确认注销", role: .destructive) {
                Task { await handleDeleteAccount() }
            }
        } message: {
            Text("此操作不可撤销。所有回忆录、照片、亲友数据将被永久删除。请输入密码确认。")
        }
    }

    // MARK: - 密码修改表单

    private var changePasswordForm: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // 旧密码
            HStack {
                if showOldPassword {
                    TextField("旧密码", text: $oldPassword)
                        .font(.system(size: DesignTokens.Typography.body))
                } else {
                    SecureField("旧密码", text: $oldPassword)
                        .font(.system(size: DesignTokens.Typography.body))
                }
                Button {
                    showOldPassword.toggle()
                } label: {
                    Image(systemName: showOldPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(MemoirColors.textTertiary)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(MemoirColors.card)
            .cornerRadius(DesignTokens.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(MemoirColors.border, lineWidth: 1)
            )

            // 新密码
            HStack {
                if showNewPassword {
                    TextField("新密码（8位以上）", text: $newPassword)
                        .font(.system(size: DesignTokens.Typography.body))
                } else {
                    SecureField("新密码（8位以上）", text: $newPassword)
                        .font(.system(size: DesignTokens.Typography.body))
                }
                Button {
                    showNewPassword.toggle()
                } label: {
                    Image(systemName: showNewPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(MemoirColors.textTertiary)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(MemoirColors.card)
            .cornerRadius(DesignTokens.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(MemoirColors.border, lineWidth: 1)
            )

            // 确认新密码
            SecureField("确认新密码", text: $confirmPassword)
                .font(.system(size: DesignTokens.Typography.body))
                .padding(DesignTokens.Spacing.md)
                .background(MemoirColors.card)
                .cornerRadius(DesignTokens.Radius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .stroke(MemoirColors.border, lineWidth: 1)
                )

            // 修改按钮
            Button {
                Task { await handleChangePassword() }
            } label: {
                Text("确认修改")
                    .font(.system(size: DesignTokens.Typography.button, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.primaryLarge)
            .disabled(!passwordChangeValid)
            .opacity(passwordChangeValid ? 1 : 0.5)
        }
        .padding(.top, DesignTokens.Spacing.sm)
    }

    // MARK: - 验证

    private var passwordChangeValid: Bool {
        oldPassword.count >= 8
        && newPassword.count >= 8
        && newPassword == confirmPassword
    }

    // MARK: - 修改密码

    private func handleChangePassword() async {
        guard passwordChangeValid else { return }
        localError = nil
        successMessage = nil

        do {
            try await authService.changePassword(oldPassword: oldPassword, newPassword: newPassword)
            successMessage = "密码修改成功"
            // 重置表单
            oldPassword = ""
            newPassword = ""
            confirmPassword = ""
            showChangePassword = false
        } catch {
            localError = "密码修改失败，请检查旧密码是否正确"
        }

        // 3 秒后清除成功提示
        if successMessage != nil {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            successMessage = nil
        }
    }

    // MARK: - 注销账号

    private func handleDeleteAccount() async {
        guard !deletePassword.isEmpty else { return }
        localError = nil

        do {
            try await authService.deleteAccount(password: deletePassword)
            // AuthService.logoutLocally 已调用，App 会自动切到登录页
        } catch {
            localError = "注销失败，请检查密码"
        }
    }
}

// MARK: - Preview

#Preview("账户设置") {
    NavigationStack {
        AccountSettingsView()
            .environmentObject(AuthService.shared)
    }
}
