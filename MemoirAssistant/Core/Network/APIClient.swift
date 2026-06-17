import Foundation

// MARK: - API 错误
enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int)
    case decodingError(Error)
    case networkError(Error)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的请求地址"
        case .unauthorized: return "登录已过期，请重新登录"
        case .serverError(let code): return "服务器错误 (\(code))"
        case .decodingError: return "数据解析失败"
        case .networkError(let err): return err.localizedDescription
        case .rateLimited: return "操作过于频繁，请稍后重试"
        }
    }
}

// MARK: - 分页响应
struct PaginatedResponse<T: Decodable>: Decodable {
    let data: [T]
    let pagination: Pagination

    struct Pagination: Decodable {
        let page: Int
        let limit: Int
        let total: Int
        let totalPages: Int
    }
}

// MARK: - API 客户端
final class APIClient: @unchecked Sendable {
    static let shared = APIClient()

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        #if DEBUG
        baseURL = "http://localhost:3002/api/v1"
        #else
        baseURL = "https://memoir-assistant.vercel.app/api/v1"
        #endif

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = 6
        config.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,   // 10MB 内存缓存
            diskCapacity: 50 * 1024 * 1024,     // 50MB 磁盘缓存
            diskPath: "memoir-api-cache"
        )
        config.requestCachePolicy = .useProtocolCachePolicy
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - JWT Token 管理
    private var authToken: String? {
        KeychainManager.shared.readToken()
    }

    // MARK: - 核心请求方法
    func request<T: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        try await requestWithRetry(
            path, method: method, body: body,
            queryItems: queryItems, authenticated: authenticated,
            maxRetries: method == .get ? 2 : 0
        )
    }

    private func requestWithRetry<T: Decodable>(
        _ path: String,
        method: HTTPMethod,
        body: Encodable?,
        queryItems: [URLQueryItem]?,
        authenticated: Bool,
        maxRetries: Int,
        attempt: Int = 1
    ) async throws -> T {
        do {
            return try await performRequest(
                path, method: method, body: body,
                queryItems: queryItems, authenticated: authenticated
            )
        } catch let error as APIError {
            // 仅对服务器错误和网络错误重试
            if attempt < maxRetries, shouldRetry(error) {
                let delay = Double(attempt) * 0.5
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await requestWithRetry(
                    path, method: method, body: body,
                    queryItems: queryItems, authenticated: authenticated,
                    maxRetries: maxRetries, attempt: attempt + 1
                )
            }
            throw error
        }
    }

    private func shouldRetry(_ error: APIError) -> Bool {
        switch error {
        case .serverError(let code): return code >= 500
        case .networkError: return true
        default: return false
        }
    }

    private func performRequest<T: Decodable>(
        _ path: String,
        method: HTTPMethod,
        body: Encodable?,
        queryItems: [URLQueryItem]?,
        authenticated: Bool
    ) async throws -> T {
        guard var components = URLComponents(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        if let queryItems = queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("memoir-ios/1.0", forHTTPHeaderField: "X-Client")

        if authenticated, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response): (Data, URLResponse)
        do {
            PerformanceMonitor.shared.networkRequestStarted()
            (data, response) = try await session.data(for: request)
        } catch {
            PerformanceMonitor.shared.networkRequestCompleted()
            throw APIError.networkError(error)
        }
        PerformanceMonitor.shared.networkRequestCompleted()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError(0)
        }

        switch httpResponse.statusCode {
        case 200, 201:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401:
            // 触发登出通知
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .sessionExpired, object: nil)
            }
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - 便捷方法

    /// GET 请求
    func get<T: Decodable>(_ path: String, query: [URLQueryItem]? = nil) async throws -> T {
        try await request(path, method: .get, queryItems: query)
    }

    /// POST 请求
    func post<T: Decodable>(_ path: String, body: Encodable) async throws -> T {
        try await request(path, method: .post, body: body)
    }

    /// PUT 请求
    func put<T: Decodable>(_ path: String, body: Encodable) async throws -> T {
        try await request(path, method: .put, body: body)
    }

    /// DELETE 请求
    func delete<T: Decodable>(_ path: String) async throws -> T {
        try await request(path, method: .delete)
    }

    /// 分页列表请求
    func paginatedGet<T: Decodable>(
        _ path: String,
        page: Int = 1,
        limit: Int = 20,
        additionalQuery: [URLQueryItem]? = nil
    ) async throws -> PaginatedResponse<T> {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let additional = additionalQuery {
            query.append(contentsOf: additional)
        }
        return try await get(path, query: query)
    }
}

// MARK: - HTTP 方法
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

// MARK: - AnyEncodable wrapper
private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

// MARK: - 通知
extension Notification.Name {
    static let sessionExpired = Notification.Name("memoir.session.expired")
}
