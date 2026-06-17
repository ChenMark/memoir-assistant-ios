import Foundation

/// 画廊 API 服务 — 列表 / 上传回调 / 评论 / 分享
final class GalleryService {
    static let shared = GalleryService()

    private let client = APIClient.shared
    private let base = "/memoir/gallery"

    private init() {}

    // MARK: - 画廊列表

    /// 获取画廊列表（支持分页）
    func fetchGallery(page: Int = 1, limit: Int = 20) async throws -> PaginatedResponse<GalleryPhoto> {
        return try await client.get("\(base)?page=\(page)&limit=\(limit)")
    }

    // MARK: - 创建画廊记录（OSS 上传成功后调用）

    func createGallery(request: GalleryCreateRequest) async throws -> GalleryPhoto {
        let resp: CreateResponse = try await client.post(base, body: request)
        return resp.item
    }

    // MARK: - 删除照片

    func deletePhoto(id: String) async throws {
        let _: EmptyResponse = try await client.delete("\(base)/\(id)")
    }

    // MARK: - 评论列表

    func fetchComments(photoId: String, page: Int = 1, limit: Int = 20) async throws -> PaginatedResponse<PhotoComment> {
        return try await client.get("\(base)/\(photoId)/comments?page=\(page)&limit=\(limit)")
    }

    // MARK: - 添加评论

    func addComment(photoId: String, content: String) async throws -> PhotoComment {
        let body = CommentBody(content: content)
        let resp: CommentCreateResponse = try await client.post("\(base)/\(photoId)/comments", body: body)
        return resp.comment
    }

    // MARK: - 删除评论

    func deleteComment(commentId: String) async throws {
        let _: EmptyResponse = try await client.delete("\(base)/comments/\(commentId)")
    }

    // MARK: - OSS 签名

    func getOSSSign(key: String, contentType: String = "image/jpeg") async throws -> String {
        let body = SignBody(key: key, contentType: contentType, method: nil)
        let resp: OSSSignResponse = try await client.post("/oss/sign", body: body)
        return resp.url
    }

    func getOSSDownloadUrl(key: String) async throws -> String {
        let body = SignBody(key: key, contentType: nil, method: nil)
        let resp: OSSDownloadResponse = try await client.post("/oss/download", body: body)
        return resp.url
    }

    // MARK: - 分享

    func generateShareLink(photoId: String) async throws -> ShareResponse {
        return try await client.post("\(base)/\(photoId)/share")
    }

    func revokeShare(photoId: String) async throws {
        let _: EmptyResponse = try await client.delete("\(base)/\(photoId)/share")
    }
}

// MARK: - Response types

extension GalleryService {
    struct CreateResponse: Codable {
        let item: GalleryPhoto
    }

    struct CommentBody: Codable {
        let content: String
    }

    struct CommentCreateResponse: Codable {
        let comment: PhotoComment
    }

    struct SignBody: Codable {
        let key: String
        let contentType: String?
        let method: String?
    }

    struct ShareResponse: Codable {
        let shareToken: String
        let shareUrl: String
    }
}

struct EmptyResponse: Codable {}

// MARK: - OSS Response types (shared)

struct OSSSignResponse: Codable {
    let url: String
}

struct OSSDownloadResponse: Codable {
    let url: String
}
