import Foundation
import UIKit
import os

// MARK: - 性能监控器

/// 监控 App 启动时间、内存使用、网络请求耗时
final class PerformanceMonitor: @unchecked Sendable {
    static let shared = PerformanceMonitor()

    private let logger = Logger(subsystem: "com.memoir.ios", category: "Performance")

    // MARK: - 启动耗时追踪

    private var launchStartTime: Date?
    private(set) var launchDuration: TimeInterval = 0

    // MARK: - 内存追踪

    private var memoryTimer: Timer?

    // MARK: - 网络状态

    private(set) var pendingNetworkRequests = 0

    private init() {}

    deinit {
        stopMemoryMonitoring()
    }

    // MARK: - 启动监控

    /// 在 App 初始化最早时机调用
    func markLaunchStart() {
        launchStartTime = Date()
        logger.info("🚀 App 启动计时开始")
    }

    /// 在首屏渲染完成时调用
    func markLaunchComplete() {
        guard let start = launchStartTime else { return }
        launchDuration = Date().timeIntervalSince(start)
        logger.info("✅ 首屏渲染完成，耗时: \(String(format: "%.2f", self.launchDuration))s")

        if launchDuration > 2.0 {
            logger.warning("⚠️ 启动时间超过 2s: \(String(format: "%.2f", self.launchDuration))s")
        }
    }

    // MARK: - 内存监控

    var currentMemoryUsage: UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    var memoryUsageMB: Double {
        Double(currentMemoryUsage) / 1_048_576
    }

    func startMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let memMB = self.memoryUsageMB

            if memMB > 200 {
                self.logger.warning("⚠️ 内存使用过高: \(String(format: "%.0f", memMB))MB")
            }
        }
    }

    func stopMemoryMonitoring() {
        memoryTimer?.invalidate()
        memoryTimer = nil
    }

    // MARK: - 网络请求追踪

    func networkRequestStarted() {
        pendingNetworkRequests += 1
    }

    func networkRequestCompleted() {
        pendingNetworkRequests = max(0, pendingNetworkRequests - 1)
    }

    // MARK: - 诊断报告

    func diagnosticReport() -> String {
        """
        📊 忆往昔 · 性能诊断报告
        ━━━━━━━━━━━━━━━━━━━━
        启动耗时: \(String(format: "%.2f", launchDuration))s
        内存使用: \(String(format: "%.1f", memoryUsageMB))MB
        待处理请求: \(pendingNetworkRequests)
        ━━━━━━━━━━━━━━━━━━━━
        """
    }
}
