import Foundation

/// 回忆录模型
struct Memoir: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let content: String
    let tags: [String]
    let mood: String?
    let location: String?
    let date: String
    let media: [String]
    let isPublished: Bool
    let createdAt: Date
    let updatedAt: Date

    static func == (lhs: Memoir, rhs: Memoir) -> Bool {
        lhs.id == rhs.id
    }
}

/// 草稿模型
struct Draft: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let content: String
    let tags: [String]
    let mood: String?
    let date: String?
    let media: [String]
    let createdAt: Date
    let updatedAt: Date

    static func == (lhs: Draft, rhs: Draft) -> Bool {
        lhs.id == rhs.id
    }
}

/// 回忆录创建/更新请求
struct MemoirRequest: Encodable {
    let title: String
    let content: String?
    let date: String?
    let tags: [String]?
    let mood: String?
    let location: String?
    let media: [String]?
}
