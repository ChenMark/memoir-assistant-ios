import Foundation
import SwiftUI

/// 认证状态管理
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// 是否启用生物识别（Face ID / Touch ID）
    @AppStorage("biometric_enabled") var biometricEnabled: Bool = false

    private let api = APIClient.shared

    private init() {
        if KeychainManager.shared.readToken() != nil {
            Task { await checkSession() }
        }
    }

    // MARK: - 会话检查

    func checkSession() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: MeResponse = try await api.get("/auth/me")
            self.currentUser = response.user
            self.isAuthenticated = true
            self.errorMessage = nil
            return true
        } catch {
            self.logoutLocally()
            return false
        }
    }

    // MARK: - 邮箱注册

    func register(username: String, email: String, password: String, phone: String? = nil) async throws {
        isLoading = true
        defer { isLoading = false }

        let request = RegisterRequest(username: username, email: email, password: password, phone: phone)
        let response: AuthResponse = try await api.post("/auth/register", body: request, authenticated: false)
        handleAuthResponse(response)
    }

    // MARK: - 账号密码登录

    func login(account: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let request = LoginRequest(account: account, password: password)
        let response: AuthResponse = try await api.post("/auth/login", body: request, authenticated: false)
        handleAuthResponse(response)
    }

    // MARK: - 短信验证码登录

    func phoneLogin(phone: String, code: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let request = PhoneLoginRequest(phone: phone, code: code)
        let response: AuthResponse = try await api.post("/auth/phone-login", body: request, authenticated: false)
        handleAuthResponse(response)
    }

    // MARK: - 发送短信验证码

    func sendSMS(phone: String) async throws {
        let request = SMSRequest(phone: phone)
        let _: SMSResponse = try await api.post("/auth/send-sms", body: request, authenticated: false)
    }

    // MARK: - 微信 / QQ OAuth URL

    func getOAuthURL(provider: OAuthProvider) async throws -> URL {
        let path = provider == .wechat ? "/auth/wechat-auth" : "/auth/qq-auth"
        let config: OAuthConfig = try await api.get(path, authenticated: false) as OAuthConfig
        guard let url = URL(string: config.authUrl) else {
            throw APIError.invalidURL
        }
        return url
    }

    /// 模拟 OAuth 演示模式登录（无 AppId 时后端走演示）
    func demoOAuthLogin(provider: OAuthProvider) async throws {
        isLoading = true
        defer { isLoading = false }

        let path = provider == .wechat ? "/auth/wechat" : "/auth/qq"
        let response: AuthResponse = try await api.get(path, authenticated: false) as AuthResponse
        handleAuthResponse(response)
    }

    // MARK: - 个人资料

    /// 更新用户资料（用户名 / bio）
    func updateProfile(username: String? = nil, bio: String? = nil) async throws {
        isLoading = true
        defer { isLoading = false }

        let request = UpdateProfileRequest(username: username, bio: bio)
        let response: MeResponse = try await api.put("/auth/me", body: request)
        self.currentUser = response.user
    }

    // MARK: - 密码修改

    func changePassword(oldPassword: String, newPassword: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let request = ChangePasswordRequest(old_password: oldPassword, new_password: newPassword)
        let _: MessageResponse = try await api.post("/auth/change-password", body: request)
    }

    // MARK: - 账号注销

    func deleteAccount(password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let body = ["password": password]
        let _: MessageResponse = try await api.post("/auth/delete-account", body: body)
        logoutLocally()
    }

    // MARK: - 登出

    func logout() {
        logoutLocally()
    }

    // MARK: - 私有方法

    private func handleAuthResponse(_ response: AuthResponse) {
        KeychainManager.shared.saveToken(response.token)
        self.currentUser = response.user
        self.isAuthenticated = true
        self.errorMessage = nil
    }

    private func logoutLocally() {
        KeychainManager.shared.deleteToken()
        self.currentUser = nil
        self.isAuthenticated = false
    }
}

// MARK: - OAuth 提供商

enum OAuthProvider {
    case wechat, qq

    var name: String { self == .wechat ? "微信" : "QQ" }
    var icon: String { self == .wechat ? "message.fill" : "circle.fill" }
    var color: String { self == .wechat ? "#07C160" : "#12B7F5" }
}
