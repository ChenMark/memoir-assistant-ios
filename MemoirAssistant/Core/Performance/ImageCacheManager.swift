import UIKit
import Foundation
import CommonCrypto
import os

// MARK: - 全局图片缓存管理器

/// 统一管理图片缓存，解决 Each-instance NSCache 无效问题
/// 策略：内存 LRU (50MB) → 磁盘缓存 (200MB) → 网络
final class ImageCacheManager: @unchecked Sendable {
    static let shared = ImageCacheManager()

    // MARK: - 内存缓存
    private let memoryCache = NSCache<NSString, UIImage>()

    // MARK: - 磁盘缓存
    private let diskCacheURL: URL
    private let fileManager = FileManager.default
    private let diskCacheQueue = DispatchQueue(label: "memoir.imagecache.disk", qos: .utility)

    // MARK: - 配置
    private let memoryCacheLimit = 50 * 1024 * 1024  // 50MB
    private let diskCacheLimit = 200 * 1024 * 1024   // 200MB

    private init() {
        // 内存缓存配置
        memoryCache.totalCostLimit = memoryCacheLimit
        memoryCache.countLimit = 200

        // 磁盘缓存路径
        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cachesDir.appendingPathComponent("MemoirImageCache")
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // 监听内存警告
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    // MARK: - 公共 API

    /// 异步加载图片（内存 → 磁盘 → 网络）
    func loadImage(from urlString: String) async -> UIImage? {
        let cacheKey = cacheKey(from: urlString)

        // 1. 内存缓存
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            return cached
        }

        // 2. 磁盘缓存
        if let diskCached = await loadFromDisk(key: cacheKey) {
            memoryCache.setObject(diskCached, forKey: cacheKey as NSString)
            return diskCached
        }

        // 3. 网络加载
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                os_log(.error, "[ImageCache] 图片数据解码失败: %{public}@", urlString)
                return nil
            }

            // 写入缓存
            memoryCache.setObject(image, forKey: cacheKey as NSString)
            await saveToDisk(image: image, key: cacheKey)

            return image
        } catch {
            // 非关键错误（网络超时/断开），降级到不缓存
            os_log(.error, "[ImageCache] 网络加载失败: %{public}@ — %{public}@", urlString, error.localizedDescription)
            return nil
        }
    }

    /// 预加载图片列表（后台低优先级）
    func prefetchImages(_ urls: [String]) {
        for url in urls {
            Task.detached(priority: .background) {
                _ = await self.loadImage(from: url)
            }
        }
    }

    /// 清除所有缓存
    func clearAll() {
        memoryCache.removeAllObjects()
        diskCacheQueue.async {
            do {
                if self.fileManager.fileExists(atPath: self.diskCacheURL.path) {
                    try self.fileManager.removeItem(at: self.diskCacheURL)
                }
                try self.fileManager.createDirectory(at: self.diskCacheURL, withIntermediateDirectories: true)
            } catch {
                os_log(.error, "[ImageCache] 清除磁盘缓存失败: %{public}@", error.localizedDescription)
            }
        }
    }

    /// 清除内存缓存（保留磁盘）
    func clearMemory() {
        memoryCache.removeAllObjects()
    }

    // MARK: - 私有方法

    private func cacheKey(from url: String) -> String {
        // SHA256 前 16 字节 → 32 hex 字符，2^128 空间，无碰撞
        guard let data = url.data(using: .utf8) else { return url }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) }
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private func loadFromDisk(key: String) async -> UIImage? {
        await withCheckedContinuation { continuation in
            diskCacheQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                let fileURL = self.diskCacheURL.appendingPathComponent(key)
                guard let data = try? Data(contentsOf: fileURL),
                      let image = UIImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }

    private func saveToDisk(image: UIImage, key: String) async {
        await withCheckedContinuation { continuation in
            diskCacheQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                let fileURL = self.diskCacheURL.appendingPathComponent(key)
                if let data = image.jpegData(compressionQuality: 0.85) {
                    do {
                        try data.write(to: fileURL)
                    } catch {
                        os_log(.error, "[ImageCache] 磁盘写入失败: %{public}@ — %{public}@", key, error.localizedDescription)
                    }
                }
                // 写入后检查磁盘限额
                self.trimDiskCacheIfNeeded()
                continuation.resume()
            }
        }
    }

    /// 磁盘缓存超过限额时，删除最旧文件
    private func trimDiskCacheIfNeeded() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        // 1. 计算总大小
        let totalSize = contents.reduce(0) { acc, url in
            acc + (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        }

        guard totalSize > diskCacheLimit else { return }

        // 2. 按修改时间排序，删除最旧文件直到低于限额
        let sorted = (try? contents.sorted { a, b in
            let aDate = try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            let bDate = try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            return (aDate ?? .distantPast) < (bDate ?? .distantPast)
        }) ?? []

        var removedSize = 0
        let targetSize = diskCacheLimit * 3 / 4 // 降至 75% 限额

        for url in sorted {
            guard totalSize - removedSize > targetSize else { break }
            let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            do {
                try fileManager.removeItem(at: url)
                removedSize += fileSize
            } catch {
                os_log(.error, "[ImageCache] 清理旧缓存文件失败: %{public}@", url.lastPathComponent)
            }
        }

        if removedSize > 0 {
            os_log(.info, "[ImageCache] 磁盘缓存清理完成，释放 %{public}.1f MB", Double(removedSize) / 1_048_576)
        }
    }

    @objc private func handleMemoryWarning() {
        memoryCache.removeAllObjects()
    }
}
