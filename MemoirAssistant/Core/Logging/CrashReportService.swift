import Foundation
import UIKit

// MARK: - 崩溃收集与诊断服务

/// 管理全局异常捕获、崩溃上下文记录、启动诊断
final class CrashReportService: @unchecked Sendable {
    static let shared = CrashReportService()

    // MARK: - 崩溃上下文

    private(set) var lastScreen: String = "launch"
    private(set) var sessionStartTime: Date
    private var breadcrumbs: [String] = []
    private let maxBreadcrumbs = 50

    private let logger = LogService.shared

    private init() {
        sessionStartTime = Date()
        setupExceptionHandler()
    }

    // MARK: - 异常捕获

    private func setupExceptionHandler() {
        // 捕获未处理的 NSException
        NSSetUncaughtExceptionHandler { exception in
            CrashReportService.shared.handleException(exception)
        }

        // 监听信号
        signal(SIGABRT) { _ in CrashReportService.shared.handleSignal("SIGABRT") }
        signal(SIGILL)  { _ in CrashReportService.shared.handleSignal("SIGILL") }
        signal(SIGSEGV) { _ in CrashReportService.shared.handleSignal("SIGSEGV") }
        signal(SIGBUS)  { _ in CrashReportService.shared.handleSignal("SIGBUS") }
        signal(SIGTRAP) { _ in CrashReportService.shared.handleSignal("SIGTRAP") }
    }

    private func handleException(_ exception: NSException) {
        let crashInfo = """
        🚨 未捕获的异常
        ━━━━━━━━━━━━━━━━━━━━
        名称: \(exception.name.rawValue)
        原因: \(exception.reason ?? "未知")
        用户信息: \(exception.userInfo ?? [:])
        调用栈:
        \(exception.callStackSymbols.joined(separator: "\n"))
        ━━━━━━━━━━━━━━━━━━━━
        面包屑:
        \(breadcrumbs.joined(separator: "\n"))
        ━━━━━━━━━━━━━━━━━━━━
        最后屏幕: \(lastScreen)
        会话时长: \(String(format: "%.0f", Date().timeIntervalSince(sessionStartTime)))s
        """

        logger.critical(crashInfo)

        // 保存到文件
        saveCrashLog(crashInfo)
    }

    private func handleSignal(_ name: String) {
        logger.critical("🚨 收到信号: \(name) | 屏幕: \(self.lastScreen)")
    }

    // MARK: - 面包屑追踪

    /// 记录用户操作轨迹，帮助复现崩溃路径
    func leaveBreadcrumb(_ action: String) {
        let entry = "[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))] \(action)"
        breadcrumbs.append(entry)
        if breadcrumbs.count > maxBreadcrumbs {
            breadcrumbs.removeFirst(breadcrumbs.count - maxBreadcrumbs)
        }
    }

    /// 更新当前屏幕名
    func setCurrentScreen(_ name: String) {
        lastScreen = name
    }

    // MARK: - 启动诊断

    func startupDiagnostic() -> String {
        let device = UIDevice.current
        let memory = PerformanceMonitor.shared.memoryUsageMB

        return """
        📱 设备信息
        ━━━━━━━━━━━━━━━━━━━━
        设备: \(device.model)
        系统: \(device.systemName) \(device.systemVersion)
        内存: \(String(format: "%.0f", memory))MB
        App 版本: 1.6.0 (M7)
        启动耗时: \(String(format: "%.2f", PerformanceMonitor.shared.launchDuration))s
        ━━━━━━━━━━━━━━━━━━━━
        """
    }

    // MARK: - 持久化

    private func saveCrashLog(_ log: String) {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }

        let crashDir = dir.appendingPathComponent("CrashLogs")
        try? FileManager.default.createDirectory(at: crashDir, withIntermediateDirectories: true)

        let dateStr = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let fileURL = crashDir.appendingPathComponent("crash-\(dateStr).log")
        try? log.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// 获取最近的崩溃日志
    func recentCrashLogs() -> [String] {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return []
        }

        let crashDir = dir.appendingPathComponent("CrashLogs")
        guard let files = try? FileManager.default.contentsOfDirectory(at: crashDir, includingPropertiesForKeys: nil) else {
            return []
        }

        return files.sorted { $0.lastPathComponent > $1.lastPathComponent }
            .prefix(5)
            .compactMap { try? String(contentsOf: $0) }
    }
}
