import Foundation

// MARK: - 爱好服务

final class HobbyService {
    static let shared = HobbyService()

    private let client = APIClient.shared
    private let base = "/hobby"

    private init() {}

    // MARK: - 获取爱好列表（支持分类筛选 + 分页）

    func fetchHobbies(category: HobbyCategory? = nil, page: Int = 1, limit: Int = 20) async throws -> PaginatedResponse<Hobby> {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let category = category {
            query.append(URLQueryItem(name: "category", value: category.rawValue))
        }
        return try await client.get(base, query: query)
    }

    // MARK: - 添加爱好

    func addHobby(_ request: HobbyRequest) async throws -> HobbyResponse {
        return try await client.post(base, body: request)
    }

    // MARK: - 更新爱好

    func updateHobby(id: String, _ request: HobbyRequest) async throws -> HobbyResponse {
        return try await client.put("\(base)/\(id)", body: request)
    }

    // MARK: - 删除爱好

    func deleteHobby(id: String) async throws {
        let _: EmptyResponse = try await client.delete("\(base)/\(id)")
    }
}

struct HobbyResponse: Codable {
    let hobby: Hobby
}
