import Foundation

/// 爱好模型
struct Hobby: Codable, Identifiable, Equatable {
    let id: String
    let category: HobbyCategory
    let title: String
    let description: String?
    let rating: Int?
    let year: String?
    let link: String?
    let tags: [String]
    let imageKey: String?
    let createdAt: Date

    static func == (lhs: Hobby, rhs: Hobby) -> Bool {
        lhs.id == rhs.id
    }
}

enum HobbyCategory: String, Codable, CaseIterable {
    case music
    case movie
    case sport
    case custom

    var displayName: String {
        switch self {
        case .music: return "金曲"
        case .movie: return "电影"
        case .sport: return "比赛"
        case .custom: return "自定义"
        }
    }

    var icon: String {
        switch self {
        case .music: return "🎵"
        case .movie: return "🎬"
        case .sport: return "🏆"
        case .custom: return "✨"
        }
    }
}

/// 爱好创建/更新请求
struct HobbyRequest: Encodable {
    let category: String
    let title: String
    let description: String?
    let rating: Int?
    let year: String?
    let link: String?
    let tags: [String]?
}
