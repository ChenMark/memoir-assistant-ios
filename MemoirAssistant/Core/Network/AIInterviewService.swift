import Foundation

// MARK: - AI 访谈 API 服务

@MainActor
final class AIInterviewService: ObservableObject {
    static let shared = AIInterviewService()

    private let api = APIClient.shared
    private let baseURL: String

    private init() {
        #if DEBUG
        baseURL = "http://localhost:3002/api/v1"
        #else
        baseURL = "https://memoir-assistant.vercel.app/api/v1"
        #endif
    }

    // MARK: - 数据类型

    struct AIDimension: Decodable, Identifiable {
        let id: String
        let name: String
        let description: String
        let icon: String
        let prompt: String
    }

    struct ChatMessage: Codable, Identifiable {
        let id: String
        let role: String       // "user" | "assistant"
        let content: String
        var isStreaming: Bool = false

        init(id: String = UUID().uuidString, role: String, content: String, isStreaming: Bool = false) {
            self.id = id
            self.role = role
            self.content = content
            self.isStreaming = isStreaming
        }
    }

    struct ChatRequest: Encodable {
        let messages: [ChatMessagePayload]
        let dimensionId: String?
    }

    struct ChatMessagePayload: Encodable {
        let role: String
        let content: String
    }

    struct ChatResponse: Decodable {
        let success: Bool
        let data: ChatData?
    }

    struct ChatData: Decodable {
        let message: String
        let suggestions: [String]?
        let storyOutline: [StoryOutlineItem]?
    }

    struct StoryOutlineItem: Decodable, Identifiable {
        let id: String
        let title: String
        let summary: String
    }

    struct GenerateStoryRequest: Encodable {
        let messages: [ChatMessagePayload]
    }

    struct GenerateStoryResponse: Decodable {
        let success: Bool
        let data: StoryData?
    }

    struct StoryData: Decodable {
        let story: String
    }

    struct DimensionsResponse: Decodable {
        let success: Bool
        let data: [AIDimension]
    }

    // MARK: - API 调用

    /// 获取引导维度列表
    func fetchDimensions() async throws -> [AIDimension] {
        let response: DimensionsResponse = try await api.get("/ai/dimensions")
        return response.data
    }

    /// 发送聊天消息
    func sendMessage(
        messages: [ChatMessagePayload],
        dimensionId: String? = nil
    ) async throws -> ChatData {
        let request = ChatRequest(messages: messages, dimensionId: dimensionId)
        let response: ChatResponse = try await api.post("/ai/chat", body: request)
        guard let data = response.data else {
            throw APIError.serverError(500)
        }
        return data
    }

    /// 生成故事脉络
    func generateStory(messages: [ChatMessagePayload]) async throws -> String {
        let request = GenerateStoryRequest(messages: messages)
        let response: GenerateStoryResponse = try await api.post("/ai/generate-story", body: request)
        guard let story = response.data?.story else {
            throw APIError.serverError(500)
        }
        return story
    }

    // MARK: - 流式输出 (SSE)

    /// 流式聊天 — 通过 SSE 逐字输出
    func streamChat(
        messages: [ChatMessagePayload],
        dimensionId: String? = nil,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (ChatData?) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/ai/chat") else {
            onComplete(nil)
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.setValue("memoir-ios/1.0", forHTTPHeaderField: "X-Client")

        if let token = KeychainManager.shared.readToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = ChatRequest(messages: messages, dimensionId: dimensionId)
        urlRequest.httpBody = try? JSONEncoder().encode(body)

        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: urlRequest) { data, _, error in
            if let data = data, let text = String(data: data, encoding: .utf8) {
                // 尝试解析 SSE 格式，或直接作为 JSON
                if text.hasPrefix("data:") {
                    let lines = text.components(separatedBy: "\n")
                    var fullContent = ""
                    for line in lines {
                        if line.hasPrefix("data:") {
                            let content = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            if content == "[DONE]" { continue }
                            fullContent += content
                            DispatchQueue.main.async { onToken(content) }
                        }
                    }
                    DispatchQueue.main.async {
                        onComplete(ChatData(message: fullContent, suggestions: nil, storyOutline: nil))
                    }
                } else {
                    // 普通 JSON 响应
                    do {
                        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
                        DispatchQueue.main.async {
                            onToken(response.data?.message ?? "")
                            onComplete(response.data)
                        }
                    } catch {
                        DispatchQueue.main.async { onComplete(nil) }
                    }
                }
            } else {
                DispatchQueue.main.async { onComplete(nil) }
            }
        }
        task.resume()
    }
}
