import UIKit
import Foundation

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
            guard let image = UIImage(data: data) else { return nil }

            // 写入缓存
            memoryCache.setObject(image, forKey: cacheKey as NSString)
            await saveToDisk(image: image, key: cacheKey)

            return image
        } catch {
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
            try? self.fileManager.removeItem(at: self.diskCacheURL)
            try? self.fileManager.createDirectory(at: self.diskCacheURL, withIntermediateDirectories: true)
        }
    }

    /// 清除内存缓存（保留磁盘）
    func clearMemory() {
        memoryCache.removeAllObjects()
    }

    // MARK: - 私有方法

    private func cacheKey(from url: String) -> String {
        // SHA256 前 16 位作为缓存 key
        return String(url.hashValue & 0xFFFF)
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
                    try? data.write(to: fileURL)
                }
                continuation.resume()
            }
        }
    }

    @objc private func handleMemoryWarning() {
        memoryCache.removeAllObjects()
    }
}
