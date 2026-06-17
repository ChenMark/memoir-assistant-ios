import Foundation

/// 好友模型
struct Friend: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let avatar: String?
    let addedAt: Date
    let category: FriendCategory
    // 家族树
    let relationship: String?
    let generation: Int?
    let parentId: String?
    let spouseId: String?
    // 同学录
    let school: String?
    let classInfo: String?
    let graduationYear: String?
    // 朋友圈
    let metAt: String?
    let metYear: String?
    let tags: [String]

    static func == (lhs: Friend, rhs: Friend) -> Bool {
        lhs.id == rhs.id
    }
}

enum FriendCategory: String, Codable, CaseIterable {
    case family
    case classMate = "class_mate"
    case friend

    var displayName: String {
        switch self {
        case .family: return "家人"
        case .classMate: return "同学"
        case .friend: return "朋友"
        }
    }

    var icon: String {
        switch self {
        case .family: return "👨‍👩‍👧‍👦"
        case .classMate: return "🎓"
        case .friend: return "🤝"
        }
    }
}

/// 好友创建/更新请求
struct FriendRequest: Encodable {
    let name: String
    let category: String
    let avatar: String?
    let relationship: String?
    let generation: Int?
    let parentId: String?
    let spouseId: String?
    let school: String?
    let classInfo: String?
    let graduationYear: String?
    let metAt: String?
    let metYear: String?
    let tags: [String]?
}
