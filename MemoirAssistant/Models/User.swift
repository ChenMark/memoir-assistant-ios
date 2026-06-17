import Foundation

/// 用户模型
struct User: Codable, Identifiable, Equatable {
    let id: String
    let username: String
    let email: String?
    let avatar: String?
    let phone: String?
    let bio: String?

    /// 显示名（优先 username，兜底 id）
    var displayName: String {
        username.isEmpty ? id.prefix(8).appending("...") : username
    }
}

// MARK: - 请求体

/// 注册请求
struct RegisterRequest: Encodable {
    let username: String
    let email: String
    let password: String
    let phone: String?
}

/// 账号密码登录
struct LoginRequest: Encodable {
    let account: String
    let password: String
}

/// 手机号 + 验证码登录
struct PhoneLoginRequest: Encodable {
    let phone: String
    let code: String
}

/// 发送短信验证码
struct SMSRequest: Encodable {
    let phone: String
}

/// 更新用户资料
struct UpdateProfileRequest: Encodable {
    let username: String?
    let bio: String?
}

/// 修改密码
struct ChangePasswordRequest: Encodable {
    let old_password: String
    let new_password: String
}

// MARK: - 响应体

/// 认证响应（登录/注册共用）
struct AuthResponse: Codable {
    let user: User
    let token: String
}

/// 用户信息响应（GET /auth/me）
struct MeResponse: Codable {
    let user: User
}

/// 短信验证码响应
struct SMSResponse: Codable {
    let success: Bool
    let message: String
}

/// OAuth 授权 URL 响应
struct OAuthConfig: Codable {
    let authUrl: String
}

/// 通用消息响应
struct MessageResponse: Codable {
    let success: Bool?
    let message: String?
    let error: String?
    var displayMessage: String { message ?? error ?? "操作失败" }
}
