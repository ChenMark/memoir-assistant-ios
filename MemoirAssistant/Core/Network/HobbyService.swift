import Foundation

// MARK: - 爱好服务

final class HobbyService {
    static let shared = HobbyService()

    private let client = APIClient.shared
    private let base = "/api/v1/hobby"

    private init() {}

    // MARK: - 获取爱好列表（支持分类筛选 + 分页）

    func fetchHobbies(category: HobbyCategory? = nil, page: Int = 1, limit: Int = 20) async throws -> PaginatedResponse<Hobby> {
        var params: [String: String] = ["page": String(page), "limit": String(limit)]
        if let category = category {
            params["category"] = category.rawValue
        }
        return try await client.get(base, params: params)
    }

    // MARK: - 添加爱好

    func addHobby(_ request: HobbyRequest) async throws -> HobbyResponse {
        let data: [String: Any] = buildRequestBody(request)
        return try await client.post(base, body: data)
    }

    // MARK: - 更新爱好

    func updateHobby(id: String, _ request: HobbyRequest) async throws -> HobbyResponse {
        let data: [String: Any] = buildRequestBody(request)
        return try await client.put("\(base)/\(id)", body: data)
    }

    // MARK: - 删除爱好

    func deleteHobby(id: String) async throws {
        let _: EmptyResponse = try await client.delete("\(base)/\(id)")
    }

    // MARK: - Helper

    private func buildRequestBody(_ req: HobbyRequest) -> [String: Any] {
        var body: [String: Any] = [
            "category": req.category,
            "title": req.title,
        ]
        if let v = req.description { body["description"] = v }
        if let v = req.rating { body["rating"] = v }
        if let v = req.year { body["year"] = v }
        if let v = req.link { body["link"] = v }
        if let v = req.tags { body["tags"] = v }
        return body
    }
}

struct HobbyResponse: Codable {
    let hobby: Hobby
}
