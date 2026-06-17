import Foundation
import OSLog

// MARK: - 结构化日志服务

/// 基于 OSLog 的结构化日志系统
/// 支持分级、分类、持久化存储
final class LogService: @unchecked Sendable {
    static let shared = LogService()

    // MARK: - 日志子系统

    private let subsystem = "com.memoir.ios"

    // MARK: - 分类 Logger

    enum Category: String {
        case app      = "App"
        case network  = "Network"
        case auth     = "Auth"
        case memoir   = "Memoir"
        case gallery  = "Gallery"
        case ai       = "AI"
        case storage  = "Storage"
        case performance = "Performance"
        case crash    = "Crash"
    }

    private var loggers: [Category: Logger] = [:]

    private init() {
        for category in Category.allCases {
            loggers[category] = Logger(subsystem: subsystem, category: category.rawValue)
        }
    }

    // MARK: - 公共 API

    func debug(_ message: String, category: Category = .app, file: String = #file, line: Int = #line) {
        #if DEBUG
        loggers[category]?.debug("[\(fileName(from: file)):\(line)] \(message)")
        #endif
    }

    func info(_ message: String, category: Category = .app) {
        loggers[category]?.info("\(message)")
    }

    func warning(_ message: String, category: Category = .app) {
        loggers[category]?.warning("⚠️ \(message)")
    }

    func error(_ message: String, category: Category = .app, error: Error? = nil) {
        if let error = error {
            loggers[category]?.error("❌ \(message) — \(error.localizedDescription)")
        } else {
            loggers[category]?.error("❌ \(message)")
        }
    }

    func critical(_ message: String, category: Category = .crash) {
        loggers[category]?.critical("🚨 \(message)")
    }

    // MARK: - 辅助方法

    private func fileName(from path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}

// MARK: - Category CaseIterable

extension LogService.Category: CaseIterable {}
