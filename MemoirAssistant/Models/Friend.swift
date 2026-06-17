import Foundation

/// 好友模型（完整匹配后端 Friend 结构）
struct Friend: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let avatar: String?
    let addedAt: Date
    let category: FriendCategory

    // 家族树字段
    let relationship: String?
    let generation: Int?
    let parentId: String?
    let spouseId: String?

    // 同学录字段
    let school: String?
    let classInfo: String?
    let graduationYear: String?

    // 朋友圈字段
    let metAt: String?
    let metYear: String?
    let tags: [String]

    // MARK: - Codable (addedAt 是 Unix 毫秒时间戳)

    enum CodingKeys: String, CodingKey {
        case id, name, avatar, addedAt, category
        case relationship, generation, parentId, spouseId
        case school, classInfo, graduationYear
        case metAt, metYear, tags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        avatar = try c.decodeIfPresent(String.self, forKey: .avatar)
        category = try c.decode(FriendCategory.self, forKey: .category)
        relationship = try c.decodeIfPresent(String.self, forKey: .relationship)
        generation = try c.decodeIfPresent(Int.self, forKey: .generation)
        parentId = try c.decodeIfPresent(String.self, forKey: .parentId)
        spouseId = try c.decodeIfPresent(String.self, forKey: .spouseId)
        school = try c.decodeIfPresent(String.self, forKey: .school)
        classInfo = try c.decodeIfPresent(String.self, forKey: .classInfo)
        graduationYear = try c.decodeIfPresent(String.self, forKey: .graduationYear)
        metAt = try c.decodeIfPresent(String.self, forKey: .metAt)
        metYear = try c.decodeIfPresent(String.self, forKey: .metYear)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []

        // addedAt 为 Unix 毫秒时间戳
        let ts = try c.decode(Double.self, forKey: .addedAt)
        addedAt = Date(timeIntervalSince1970: ts / 1000)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(avatar, forKey: .avatar)
        try c.encode(category, forKey: .category)
        try c.encodeIfPresent(relationship, forKey: .relationship)
        try c.encodeIfPresent(generation, forKey: .generation)
        try c.encodeIfPresent(parentId, forKey: .parentId)
        try c.encodeIfPresent(spouseId, forKey: .spouseId)
        try c.encodeIfPresent(school, forKey: .school)
        try c.encodeIfPresent(classInfo, forKey: .classInfo)
        try c.encodeIfPresent(graduationYear, forKey: .graduationYear)
        try c.encodeIfPresent(metAt, forKey: .metAt)
        try c.encodeIfPresent(metYear, forKey: .metYear)
        try c.encode(tags, forKey: .tags)
        try c.encode(addedAt.timeIntervalSince1970 * 1000, forKey: .addedAt)
    }

    static func == (lhs: Friend, rhs: Friend) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - FriendCategory

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

// MARK: - FriendRequest

/// 好友创建/更新请求体
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

// MARK: - 辈分选项

enum Generation: Int, CaseIterable {
    case greatGrandparent = 3
    case grandparent = 2
    case greatUncle = 1
    case parent = 1
    case selfGen = 0
    case child = -1
    case grandchild = -2
    case greatGrandchild = -3

    var displayName: String {
        switch self {
        case .greatGrandparent, .grandparent: return "祖辈"
        case .greatUncle, .parent: return "父辈"
        case .selfGen: return "同辈"
        case .child: return "子女辈"
        case .grandchild: return "孙辈"
        case .greatGrandchild: return "曾孙辈"
        }
    }

    var compactName: String {
        switch self {
        case .greatGrandparent: return "曾祖"
        case .grandparent: return "祖辈"
        case .greatUncle: return "叔伯"
        case .parent: return "父辈"
        case .selfGen: return "同辈"
        case .child: return "子女"
        case .grandchild: return "孙辈"
        case .greatGrandchild: return "曾孙"
        }
    }

    /// 返回适合选择的 generation 列表（去重）
    static var selectableOptions: [(label: String, value: Int)] {
        [(label: "祖辈 (+3)", value: 3),
         (label: "祖辈 (+2)", value: 2),
         (label: "父辈 (+1)", value: 1),
         (label: "同辈 (0)", value: 0),
         (label: "子女辈 (-1)", value: -1),
         (label: "孙辈 (-2)", value: -2),
         (label: "曾孙辈 (-3)", value: -3)]
    }
}
