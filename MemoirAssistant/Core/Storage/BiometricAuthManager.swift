import Foundation
import LocalAuthentication

// MARK: - 生物识别管理器

final class BiometricAuthManager: @unchecked Sendable {
    static let shared = BiometricAuthManager()

    private let context = LAContext()

    private init() {}

    /// 设备支持的生物识别类型
    var biometryType: LABiometryType {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        return context.biometryType
    }

    /// 是否支持生物识别
    var isAvailable: Bool {
        biometryType != .none
    }

    /// 生物识别名称
    var biometryName: String {
        switch biometryType {
        case .faceID: return "面容 ID 解锁"
        case .touchID: return "触控 ID 解锁"
        case .none: return "生物识别"
        case .opticID: return "虹膜解锁"
        @unknown default: return "生物识别"
        }
    }

    /// SF Symbol 图标
    var biometryIcon: String {
        switch biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "eye.fill"
        default: return "lock.shield.fill"
        }
    }

    /// 发起生物识别验证
    /// - Returns: 验证是否成功
    func authenticate() async -> Bool {
        guard isAvailable else { return false }

        let reason = "使用\(biometryName)快速登录忆往昔"

        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return result
        } catch {
            print("[Biometric] 认证失败: \(error.localizedDescription)")
            return false
        }
    }
}
