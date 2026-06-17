import Foundation
import UIKit

// MARK: - OSS 直传服务

/// 负责：获取上传签名 → PUT 直传 OSS → 进度回调 → 成功后创建画廊记录
final class OSSUploadService {
    static let shared = OSSUploadService()

    private let galleryService = GalleryService.shared

    private init() {}

    // MARK: - 上传进度模型

    struct UploadProgress {
        let bytesSent: Int64
        let totalBytes: Int64
        var fraction: Double {
            totalBytes > 0 ? Double(bytesSent) / Double(totalBytes) : 0
        }
    }

    enum UploadError: LocalizedError {
        case signFailed(String)
        case uploadFailed(String)
        case createFailed(String)

        var errorDescription: String? {
            switch self {
            case .signFailed(let msg): return "获取上传签名失败：\(msg)"
            case .uploadFailed(let msg): return "上传失败：\(msg)"
            case .createFailed(let msg): return "创建记录失败：\(msg)"
            }
        }
    }

    // MARK: - 核心上传方法

    /// 上传照片到 OSS 并创建画廊记录
    /// - Parameters:
    ///   - image: 要上传的图片
    ///   - caption: 图片说明
    ///   - tags: 标签列表
    ///   - date: 拍摄日期，nil 则为当前日期
    ///   - memoirId: 关联回忆录 ID，可选
    ///   - progress: 进度回调 (0.0 ~ 1.0)
    /// - Returns: 创建成功的 GalleryPhoto
    func upload(
        image: UIImage,
        caption: String = "",
        tags: [String] = [],
        date: Date? = nil,
        memoirId: String? = nil,
        progress: @escaping (Double) -> Void
    ) async throws -> GalleryPhoto {
        // 1. 压缩图片为 JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw UploadError.uploadFailed("图片压缩失败")
        }

        // 2. 生成唯一 OSS Key
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let uuid = UUID().uuidString.prefix(8)
        let ext = "jpg"
        let ossKey = "gallery/\(timestamp)_\(uuid).\(ext)"

        // 3. 获取上传签名 URL
        let signUrl = try await galleryService.getOSSSign(key: ossKey, contentType: "image/jpeg")

        // 4. PUT 直传到 OSS
        try await uploadToOSS(url: signUrl, data: imageData, contentType: "image/jpeg", progress: progress)

        // 5. 创建画廊记录
        let formattedDate = date.map { ISO8601Formatter().string(from: $0) }
        let request = GalleryCreateRequest(
            ossKey: ossKey,
            caption: caption,
            tags: tags,
            date: formattedDate,
            memoirId: memoirId
        )

        return try await galleryService.createGallery(request: request)
    }

    // MARK: - 纯 PUT 上传（带进度）

    private func uploadToOSS(
        url: String,
        data: Data,
        contentType: String,
        progress: @escaping (Double) -> Void
    ) async throws {
        guard let requestUrl = URL(string: url) else {
            throw UploadError.uploadFailed("无效的上传 URL")
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")

        // 使用 URLSession delegate 捕获进度
        let delegate = UploadProgressDelegate(progressHandler: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            delegate.onComplete = { error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }

            let task = session.uploadTask(with: request, from: data)
            task.resume()
        }
    }

    // MARK: - 批量上传

    func uploadBatch(
        images: [(image: UIImage, caption: String)],
        tags: [String] = [],
        progress: @escaping (Int, Int, Double) -> Void
    ) async throws -> [GalleryPhoto] {
        var results: [GalleryPhoto] = []

        for (index, item) in images.enumerated() {
            let photo = try await upload(
                image: item.image,
                caption: item.caption,
                tags: tags,
                progress: { fraction in
                    progress(index, images.count, fraction)
                }
            )
            results.append(photo)
        }

        return results
    }
}

// MARK: - URLSession 上传进度代理

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    let progressHandler: (Double) -> Void
    var onComplete: ((Error?) -> Void)?

    init(progressHandler: @escaping (Double) -> Void) {
        self.progressHandler = progressHandler
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let pct = totalBytesExpectedToSend > 0
            ? Double(totalBytesSent) / Double(totalBytesExpectedToSend)
            : 0
        DispatchQueue.main.async { [weak self] in
            self?.progressHandler(pct)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // 检查 HTTP 状态码
            if let httpResponse = task.response as? HTTPURLResponse,
               httpResponse.statusCode >= 200, httpResponse.statusCode < 300 {
                // OSS 返回 200 即成功，忽略底层错误
                DispatchQueue.main.async { [weak self] in
                    self?.onComplete?(nil)
                }
                return
            }
            DispatchQueue.main.async { [weak self] in
                self?.onComplete?(error)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onComplete?(nil)
            }
        }
    }
}

// MARK: - ISO8601 格式化

private func ISO8601Formatter() -> ISO8601DateFormatter {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}
