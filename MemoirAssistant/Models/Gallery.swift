import Foundation

/// 画廊照片模型
struct GalleryPhoto: Codable, Identifiable, Equatable {
    let id: String
    let memoirId: String?
    let ossKey: String
    let caption: String?
    let tags: [String]
    let date: String?
    let createdAt: Date
    let downloadUrl: String?

    static func == (lhs: GalleryPhoto, rhs: GalleryPhoto) -> Bool {
        lhs.id == rhs.id
    }
}

/// 照片评论模型
struct PhotoComment: Codable, Identifiable, Equatable {
    let id: String
    let content: String
    let user: CommentUser
    let createdAt: Date

    static func == (lhs: PhotoComment, rhs: PhotoComment) -> Bool {
        lhs.id == rhs.id
    }
}

struct CommentUser: Codable, Equatable {
    let id: String
    let username: String
    let avatar: String?
}

/// 分享信息
struct ShareInfo: Codable {
    let url: String
    let token: String
}

/// OSS 签名响应
struct OSSSignResponse: Codable {
    let url: String
    let key: String?
}

/// OSS 下载响应
struct OSSDownloadResponse: Codable {
    let url: String
}
