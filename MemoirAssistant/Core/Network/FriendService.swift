import Foundation

// MARK: - 好友服务

final class FriendService {
    static let shared = FriendService()

    private let client = APIClient.shared
    private let base = "/api/v1/friend"

    private init() {}

    // MARK: - 获取好友列表（支持分类筛选 + 分页）

    func fetchFriends(category: FriendCategory? = nil, page: Int = 1, limit: Int = 20) async throws -> PaginatedResponse<Friend> {
        var params: [String: String] = ["page": String(page), "limit": String(limit)]
        if let category = category {
            params["category"] = category.rawValue
        }
        return try await client.get(base, params: params)
    }

    // MARK: - 获取全部好友（用于家族树等场景）

    func fetchAllFriends() async throws -> PaginatedResponse<Friend> {
        return try await fetchFriends(category: nil, page: 1, limit: 200)
    }

    // MARK: - 添加好友

    func addFriend(_ request: FriendRequest) async throws -> FriendResponse {
        let data: [String: Any] = buildRequestBody(request)
        return try await client.post(base, body: data)
    }

    // MARK: - 更新好友

    func updateFriend(id: String, _ request: FriendRequest) async throws -> FriendResponse {
        let data: [String: Any] = buildRequestBody(request)
        return try await client.put("\(base)/\(id)", body: data)
    }

    // MARK: - 删除好友

    func deleteFriend(id: String) async throws {
        let _: EmptyResponse = try await client.delete("\(base)/\(id)")
    }

    // MARK: - Helper

    private func buildRequestBody(_ req: FriendRequest) -> [String: Any] {
        var body: [String: Any] = ["name": req.name, "category": req.category]
        if let v = req.avatar { body["avatar"] = v }
        if let v = req.relationship { body["relationship"] = v }
        if let v = req.generation { body["generation"] = v }
        if let v = req.parentId { body["parentId"] = v }
        if let v = req.spouseId { body["spouseId"] = v }
        if let v = req.school { body["school"] = v }
        if let v = req.classInfo { body["classInfo"] = v }
        if let v = req.graduationYear { body["graduationYear"] = v }
        if let v = req.metAt { body["metAt"] = v }
        if let v = req.metYear { body["metYear"] = v }
        if let v = req.tags { body["tags"] = v }
        return body
    }
}

// MARK: - Response types

struct FriendResponse: Codable {
    let friend: Friend
}

struct EmptyResponse: Codable {}
