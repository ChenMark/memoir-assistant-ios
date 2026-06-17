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
        let data = try await client.get("\(base)?page=\(page)&limit=\(limit)")
        return try JSONDecoder().decode(PaginatedResponse<GalleryPhoto>.self, from: data)
    }

    // MARK: - 创建画廊记录（OSS 上传成功后调用）

    struct CreateResponse: Codable {
        let item: GalleryPhoto
    }

    func createGallery(request: GalleryCreateRequest) async throws -> GalleryPhoto {
        let data = try await client.post(base, body: request)
        let resp = try JSONDecoder().decode(CreateResponse.self, from: data)
        return resp.item
    }

    // MARK: - 删除照片

    func deletePhoto(id: String) async throws {
        _ = try await client.delete("\(base)/\(id)")
    }

    // MARK: - 评论列表

    func fetchComments(photoId: String, page: Int = 1, limit: Int = 20) async throws -> PaginatedResponse<PhotoComment> {
        let data = try await client.get("\(base)/\(photoId)/comments?page=\(page)&limit=\(limit)")
        return try JSONDecoder().decode(PaginatedResponse<PhotoComment>.self, from: data)
    }

    // MARK: - 添加评论

    struct CommentBody: Codable {
        let content: String
    }

    struct CommentCreateResponse: Codable {
        let comment: PhotoComment
    }

    func addComment(photoId: String, content: String) async throws -> PhotoComment {
        let body = CommentBody(content: content)
        let data = try await client.post("\(base)/\(photoId)/comments", body: body)
        let resp = try JSONDecoder().decode(CommentCreateResponse.self, from: data)
        return resp.comment
    }

    // MARK: - 删除评论

    func deleteComment(commentId: String) async throws {
        _ = try await client.delete("\(base)/comments/\(commentId)")
    }

    // MARK: - OSS 签名

    struct SignBody: Codable {
        let key: String
        let contentType: String?
        let method: String?
    }

    func getOSSSign(key: String, contentType: String = "image/jpeg") async throws -> String {
        let body = SignBody(key: key, contentType: contentType, method: nil)
        let data = try await client.post("/oss/sign", body: body)
        let resp = try JSONDecoder().decode(OSSSignResponse.self, from: data)
        return resp.url
    }

    func getOSSDownloadUrl(key: String) async throws -> String {
        let data = try await client.post("/oss/download", body: ["key": key])
        let resp = try JSONDecoder().decode(OSSDownloadResponse.self, from: data)
        return resp.url
    }

    // MARK: - 分享

    struct ShareResponse: Codable {
        let shareToken: String
        let shareUrl: String
    }

    func generateShareLink(photoId: String) async throws -> ShareResponse {
        let data = try await client.post("\(base)/\(photoId)/share")
        return try JSONDecoder().decode(ShareResponse.self, from: data)
    }

    func revokeShare(photoId: String) async throws {
        _ = try await client.delete("\(base)/\(photoId)/share")
    }
}
