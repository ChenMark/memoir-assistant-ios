import Foundation

// MARK: - 回忆录模型 (匹配后端 Memoir 接口)

struct Memoir: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let title: String
    let content: String
    let tags: [String]
    let mood: String?
    let location: String?
    let date: String        // YYYY-MM-DD
    let media: [String]     // OSS key 列表
    let isPublished: Bool
    let createdAt: String
    let updatedAt: String

    static func == (lhs: Memoir, rhs: Memoir) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - 心情选项
    static let moodOptions: [(emoji: String, label: String, value: String)] = [
        ("😊", "开心", "happy"),
        ("😢", "伤感", "sad"),
        ("😌", "平静", "calm"),
        ("😤", "愤怒", "angry"),
        ("🤔", "思考", "thoughtful"),
        ("🥰", "温馨", "warm"),
        ("😰", "紧张", "nervous"),
        ("😴", "疲惫", "tired"),
    ]

    // MARK: - 常用标签
    static let suggestedTags = [
        "童年", "少年", "青年", "中年", "老年",
        "求学", "工作", "爱情", "婚姻", "育儿",
        "旅行", "美食", "音乐", "读书", "运动",
        "故乡", "城市", "春节", "生日", "纪念日",
        "父亲", "母亲", "兄弟姐妹", "挚友", "恩师",
    ]
}

// MARK: - 草稿模型 (匹配后端 Draft 接口)

struct Draft: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let title: String
    let content: String
    let tags: [String]
    let mood: String?
    let date: String?
    let media: [String]
    let createdAt: String
    let updatedAt: String

    static func == (lhs: Draft, rhs: Draft) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 创建/更新请求

struct CreateMemoirRequest: Encodable {
    let title: String
    let content: String?
    let date: String
    let tags: [String]?
    let mood: String?
    let location: String?
    let media: [String]?
    let isPublished: Bool?
}

struct UpdateMemoirRequest: Encodable {
    let title: String?
    let content: String?
    let date: String?
    let tags: [String]?
    let mood: String?
    let location: String?
    let media: [String]?
    let isPublished: Bool?
}

struct SaveDraftRequest: Encodable {
    let id: String?
    let title: String?
    let content: String?
    let tags: [String]?
    let mood: String?
    let date: String?
    let media: [String]?
}

// MARK: - API 响应包装

struct MemoirResponse: Decodable {
    let memoir: Memoir
}

struct DraftResponse: Decodable {
    let draft: Draft
}

struct MemoirListResponse: Decodable {
    let data: [Memoir]
    let pagination: PaginationInfo
}

struct DraftListResponse: Decodable {
    let data: [Draft]
    let pagination: PaginationInfo
}

struct PaginationInfo: Decodable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

struct SuccessResponse: Decodable {
    let success: Bool
}

// MARK: - 本地草稿 (离线暂存)

struct LocalDraft: Codable, Identifiable {
    let id: String
    var title: String
    var content: String
    var tags: [String]
    var mood: String?
    var date: String?
    var media: [String]
    var savedAt: Date
    var serverDraftId: String?  // 关联服务端草稿 ID
}
