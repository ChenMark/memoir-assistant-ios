import Foundation

// MARK: - 好友服务

final class FriendService {
    static let shared = FriendService()

    private let client = APIClient.shared
    private let base = "/friend"

    private init() {}

    // MARK: - 获取好友列表（支持分类筛选 + 分页）

    func fetchFriends(category: FriendCategory? = nil, page: Int = 1, limit: Int = 20) async throws -> PaginatedResponse<Friend> {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let category = category {
            query.append(URLQueryItem(name: "category", value: category.rawValue))
        }
        return try await client.get(base, query: query)
    }

    // MARK: - 获取全部好友（用于家族树等场景）

    func fetchAllFriends() async throws -> PaginatedResponse<Friend> {
        return try await fetchFriends(category: nil, page: 1, limit: 200)
    }

    // MARK: - 添加好友

    func addFriend(_ request: FriendRequest) async throws -> FriendResponse {
        return try await client.post(base, body: request)
    }

    // MARK: - 更新好友

    func updateFriend(id: String, _ request: FriendRequest) async throws -> FriendResponse {
        return try await client.put("\(base)/\(id)", body: request)
    }

    // MARK: - 删除好友

    func deleteFriend(id: String) async throws {
        let _: EmptyResponse = try await client.delete("\(base)/\(id)")
    }
}

// MARK: - Response types

struct FriendResponse: Codable {
    let friend: Friend
}

