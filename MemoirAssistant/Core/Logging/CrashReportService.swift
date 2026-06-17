import Foundation
import UIKit
import Darwin // sigaction, write, fsync, raise

// MARK: - 崩溃收集与诊断服务
// 设计原则：信号处理器只使用异步信号安全函数（man 7 signal-safety）
// logger.critical() 不是异步信号安全的，不能在信号处理器中调用

final class CrashReportService: @unchecked Sendable {
    static let shared = CrashReportService()

    // MARK: - 崩溃上下文

    private(set) var lastScreen: String = "launch"
    private(set) var sessionStartTime: Date
    private var breadcrumbs: [String] = []
    private let maxBreadcrumbs = 50

    private let logger = LogService.shared

    // 信号处理器专用的文件描述符（在 init 中打开，信号处理器中只做 write(fd, ...)）
    private var signalLogFD: Int32 = -1
    // 标记是否已安装信号处理器（防止重复初始化）
    private static var signalHandlersInstalled = false

    private init() {
        sessionStartTime = Date()
        prepareSignalLogFile()
        setupExceptionHandler()
        setupSignalHandlers()
    }

    // MARK: - 信号日志文件准备

    /// 在 init 阶段打开文件描述符，供信号处理器异步信号安全地写入
    private func prepareSignalLogFile() {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let crashDir = dir.appendingPathComponent("CrashLogs")
        try? FileManager.default.createDirectory(at: crashDir, withIntermediateDirectories: true)

        let dateStr = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let fileURL = crashDir.appendingPathComponent("signal-\(dateStr).log")

        // open() 是异步信号安全的系统调用，在 init 阶段调用
        let fd = open(fileURL.path, O_WRONLY | O_CREAT | O_APPEND, 0o644)
        if fd >= 0 {
            signalLogFD = fd
        } else {
            // 无法创建文件，记录到 OSLog（此时不在信号上下文中，安全）
            logger.error("无法创建信号日志文件: \(errno)")
        }
    }

    // MARK: - NSException 处理器（安全，运行在主线程）

    private func setupExceptionHandler() {
        NSSetUncaughtExceptionHandler { [weak self] exception in
            self?.handleException(exception)
        }
    }

    private func handleException(_ exception: NSException) {
        let crashInfo = """
        🚨 未捕获的异常
        ━━━━━━━━━━━━━━━━━━━
        名称: \(exception.name.rawValue)
        原因: \(exception.reason ?? "未知")
        用户信息: \(exception.userInfo ?? [:])
        调用栈:
        \(exception.callStackSymbols.joined(separator: "\n"))
        ━━━━━━━━━━━━━━━━━━━
        面包屑:
        \(breadcrumbs.joined(separator: "\n"))
        ━━━━━━━━━━━━━━━━━━━
        最后屏幕: \(lastScreen)
        会话时长: \(String(format: "%.0f", Date().timeIntervalSince(sessionStartTime)))s
        """

        logger.critical(crashInfo)
        saveCrashLog(crashInfo)
    }

    // MARK: - 信号处理器（仅使用异步信号安全函数）

    /// 信号处理器：只调用异步信号安全函数（write, fsync, raise）
    /// 完整列表见: man 7 signal-safety
    private static let signalHandler: @convention(c) (CInt) -> Void = { signalNum in
        let service = CrashReportService.shared

        // 1. 写入信号编号到预打开的文件描述符（write 是异步信号安全的）
        if service.signalLogFD >= 0 {
            let msg = "Signal received: \(signalNum)\n"
            _ = msg.withCString { ptr in
                write(service.signalLogFD, ptr, strlen(ptr))
            }
            // fsync 是异步信号安全的
            fsync(service.signalLogFD)
        }

        // 2. 恢复默认处理器并重新触发信号，让系统生成标准崩溃报告
        // raise() 是异步信号安全的
        raise(signalNum)
    }

    private func setupSignalHandlers() {
        // 防止重复安装
        guard !Self.signalHandlersInstalled else { return }
        Self.signalHandlersInstalled = true

        var sa = sigaction()
        sigemptyset(&sa.sa_mask)
        sa.sa_handler = Self.signalHandler
        sa.sa_flags = 0

        // 使用 sigaction 而非 signal()（sigaction 行为更可预测）
        let signals: [CInt] = [SIGABRT, SIGILL, SIGSEGV, SIGBUS, SIGTRAP]
        for sig in signals {
            var oldAction = sigaction()
            if sigaction(sig, &sa, &oldAction) == -1 {
                logger.error("sigaction 安装失败 for signal \(sig): \(errno)")
            }
        }
    }

    deinit {
        // 关闭文件描述符
        if signalLogFD >= 0 {
            close(signalLogFD)
            signalLogFD = -1
        }
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
        ━━━━━━━━━━━━━━━━━━━
        设备: \(device.model)
        系统: \(device.systemName) \(device.systemVersion)
        内存: \(String(format: "%.0f", memory))MB
        App 版本: 1.7.0 (iPad)
        启动耗时: \(String(format: "%.2f", PerformanceMonitor.shared.launchDuration))s
        ━━━━━━━━━━━━━━━━━━━
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
