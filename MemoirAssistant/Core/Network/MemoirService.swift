import Foundation

// MARK: - 回忆录 API 服务

@MainActor
final class MemoirService: ObservableObject {
    static let shared = MemoirService()

    private let api = APIClient.shared

    private init() {}

    // MARK: - 回忆录 CRUD

    /// 获取回忆录列表 (分页)
    func fetchMemoirs(page: Int = 1, limit: Int = 20) async throws -> MemoirListResponse {
        try await api.paginatedGet("/memoir", page: page, limit: limit)
    }

    /// 获取单条回忆录
    func fetchMemoir(id: String) async throws -> Memoir {
        let response: MemoirResponse = try await api.get("/memoir/\(id)")
        return response.memoir
    }

    /// 创建回忆录
    func createMemoir(_ request: CreateMemoirRequest) async throws -> Memoir {
        let response: MemoirResponse = try await api.post("/memoir", body: request)
        return response.memoir
    }

    /// 更新回忆录
    func updateMemoir(id: String, _ request: UpdateMemoirRequest) async throws -> Memoir {
        let response: MemoirResponse = try await api.put("/memoir/\(id)", body: request)
        return response.memoir
    }

    /// 删除回忆录
    func deleteMemoir(id: String) async throws {
        let _: SuccessResponse = try await api.delete("/memoir/\(id)")
    }

    // MARK: - 草稿 CRUD

    /// 获取草稿列表 (分页)
    func fetchDrafts(page: Int = 1, limit: Int = 20) async throws -> DraftListResponse {
        try await api.paginatedGet("/memoir/draft", page: page, limit: limit)
    }

    /// 保存草稿
    func saveDraft(_ request: SaveDraftRequest) async throws -> Draft {
        let response: DraftResponse = try await api.post("/memoir/draft", body: request)
        return response.draft
    }

    /// 删除草稿
    func deleteDraft(id: String) async throws {
        let _: SuccessResponse = try await api.delete("/memoir/draft/\(id)")
    }

    // MARK: - 搜索与筛选

    /// 搜索回忆录
    func searchMemoirs(
        keyword: String? = nil,
        mood: String? = nil,
        tag: String? = nil,
        dateFrom: String? = nil,
        dateTo: String? = nil,
        page: Int = 1,
        limit: Int = 20
    ) async throws -> MemoirListResponse {
        var query: [URLQueryItem] = []

        if let kw = keyword, !kw.isEmpty {
            query.append(URLQueryItem(name: "keyword", value: kw))
        }
        if let m = mood {
            query.append(URLQueryItem(name: "mood", value: m))
        }
        if let t = tag {
            query.append(URLQueryItem(name: "tag", value: t))
        }
        if let df = dateFrom {
            query.append(URLQueryItem(name: "date_from", value: df))
        }
        if let dt = dateTo {
            query.append(URLQueryItem(name: "date_to", value: dt))
        }

        return try await api.paginatedGet("/memoir", page: page, limit: limit, additionalQuery: query)
    }
}
