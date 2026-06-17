import SwiftUI

// MARK: - 个人资料页

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService

    @State private var isEditing = false
    @State private var editUsername = ""
    @State private var editBio = ""
    @State private var isSaving = false
    @State private var localError: String?

    var body: some View {
        List {
            // 头像区
            Section {
                HStack(spacing: DesignTokens.Spacing.lg) {
                    // 头像
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [MemoirColors.wood, MemoirColors.primaryLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)

                        Text(userInitials)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        Text(authService.currentUser?.displayName ?? "--")
                            .font(.system(size: DesignTokens.Typography.title2, weight: .bold))
                            .foregroundColor(MemoirColors.textPrimary)

                        Text(authService.currentUser?.email ?? "未绑定邮箱")
                            .font(.system(size: DesignTokens.Typography.bodySmall))
                            .foregroundColor(MemoirColors.textSecondary)
                    }

                    Spacer()

                    Button(isEditing ? "完成" : "编辑") {
                        if isEditing {
                            saveProfile()
                        } else {
                            enterEditMode()
                        }
                    }
                    .font(.system(size: DesignTokens.Typography.bodySmall, weight: .medium))
                    .foregroundColor(MemoirColors.primary)
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
            }

            // 信息区
            Section("基本信息") {
                if isEditing {
                    editingFields
                } else {
                    viewingFields
                }
            }

            // 错误提示
            if let error = localError {
                Section {
                    errorBanner(error)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MemoirColors.background)
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - 用户信息

    private var userInitials: String {
        guard let user = authService.currentUser else { return "?" }
        return String(user.displayName.prefix(1))
    }

    // MARK: - 查看模式

    private var viewingFields: some View {
        Group {
            infoRow(label: "用户名", value: authService.currentUser?.username ?? "--")
            infoRow(label: "邮箱", value: authService.currentUser?.email ?? "未绑定")
            infoRow(label: "手机号", value: authService.currentUser?.phone ?? "未绑定")
            infoRow(label: "简介", value: authService.currentUser?.bio ?? "暂无简介")
            infoRow(label: "账号 ID", value: authService.currentUser?.id ?? "--")
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: DesignTokens.Typography.body))
                .foregroundColor(MemoirColors.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: DesignTokens.Typography.body))
                .foregroundColor(MemoirColors.textSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, DesignTokens.Spacing.xxs)
    }

    // MARK: - 编辑模式

    private var editingFields: some View {
        Group {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text("用户名")
                    .font(.system(size: DesignTokens.Typography.bodySmall, weight: .medium))
                    .foregroundColor(MemoirColors.textPrimary)

                TextField("2-20个字符", text: $editUsername)
                    .font(.system(size: DesignTokens.Typography.body))
                    .padding(DesignTokens.Spacing.sm)
                    .background(MemoirColors.card)
                    .cornerRadius(DesignTokens.Radius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                            .stroke(MemoirColors.border, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text("简介")
                    .font(.system(size: DesignTokens.Typography.bodySmall, weight: .medium))
                    .foregroundColor(MemoirColors.textPrimary)

                TextField("介绍一下自己...", text: $editBio, axis: .vertical)
                    .font(.system(size: DesignTokens.Typography.body))
                    .lineLimit(3...6)
                    .padding(DesignTokens.Spacing.sm)
                    .background(MemoirColors.card)
                    .cornerRadius(DesignTokens.Radius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                            .stroke(MemoirColors.border, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - 编辑逻辑

    private func enterEditMode() {
        editUsername = authService.currentUser?.username ?? ""
        editBio = authService.currentUser?.bio ?? ""
        isEditing = true
    }

    private func saveProfile() {
        guard !editUsername.trimmingCharacters(in: .whitespaces).isEmpty else {
            localError = "用户名不能为空"
            return
        }

        isSaving = true
        localError = nil

        Task {
            do {
                try await authService.updateProfile(
                    username: editUsername.trimmingCharacters(in: .whitespaces),
                    bio: editBio.trimmingCharacters(in: .whitespaces)
                )
                isEditing = false
            } catch {
                localError = "保存失败，请稍后重试"
            }
            isSaving = false
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(.system(size: DesignTokens.Typography.bodySmall))
        }
        .foregroundColor(MemoirColors.danger)
    }
}

// MARK: - Preview

#Preview("个人资料") {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthService.shared)
    }
}
