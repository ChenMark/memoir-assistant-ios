import Foundation

// MARK: - 画廊照片模型（完整匹配后端 GalleryItem 接口）

struct GalleryPhoto: Codable, Identifiable, Equatable {
    let id: String
    let userId: String?
    let memoirId: String?
    let ossKey: String
    let caption: String
    let tags: [String]
    let date: String?
    let createdAt: String
    let downloadUrl: String?
    let commentCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, userId, memoirId, ossKey, caption, tags, date, createdAt, downloadUrl, commentCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = try c.decodeIfPresent(String.self, forKey: .userId)
        memoirId = try c.decodeIfPresent(String.self, forKey: .memoirId)
        ossKey = try c.decode(String.self, forKey: .ossKey)
        caption = try c.decode(String.self, forKey: .caption)
        date = try c.decodeIfPresent(String.self, forKey: .date)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        downloadUrl = try c.decodeIfPresent(String.self, forKey: .downloadUrl)
        commentCount = try c.decodeIfPresent(Int.self, forKey: .commentCount)

        // tags 从 JSON String 或 Array 解析
        if let tagsArr = try? c.decode([String].self, forKey: .tags) {
            tags = tagsArr
        } else if let tagsStr = try? c.decode(String.self, forKey: .tags) {
            tags = (try? JSONDecoder().decode([String].self, from: Data(tagsStr.utf8))) ?? []
        } else {
            tags = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(userId, forKey: .userId)
        try c.encodeIfPresent(memoirId, forKey: .memoirId)
        try c.encode(ossKey, forKey: .ossKey)
        try c.encode(caption, forKey: .caption)
        try c.encode(tags, forKey: .tags)
        try c.encodeIfPresent(date, forKey: .date)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(downloadUrl, forKey: .downloadUrl)
        try c.encodeIfPresent(commentCount, forKey: .commentCount)
    }

    static func == (lhs: GalleryPhoto, rhs: GalleryPhoto) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 照片评论模型

struct PhotoComment: Codable, Identifiable, Equatable {
    let id: String
    let content: String
    let user: CommentUser
    let createdAt: String

    static func == (lhs: PhotoComment, rhs: PhotoComment) -> Bool {
        lhs.id == rhs.id
    }
}

struct CommentUser: Codable, Equatable {
    let id: String
    let username: String
    let avatar: String?
}

// MARK: - 画廊创建请求体

// MARK: - 分享信息响应

struct ShareInfo: Codable {
    let shareToken: String
    let shareUrl: String
}

// MARK: - 画廊创建请求体

struct GalleryCreateRequest: Codable {
    let ossKey: String
    let caption: String
    let tags: [String]
    let date: String?
    let memoirId: String?
}
