import Foundation

// AIAssistantRepository AI 助手数据仓库协议
// 核心职责：
// - 定义流式聊天、历史列表和消息详情 API
// - 隔离 HTTP SSE 解析与展示层状态
protocol AIAssistantRepository {
    func openChatStream(
        message: String,
        selectedPetID: String?,
        surface: String,
        chatSessionID: String?
    ) -> AsyncThrowingStream<AIStreamEventDTO, Error>

    func fetchChatSessions() async throws(MHBAPIError) -> MHBAPIResponse<[AIChatSessionDTO]>
    func fetchSessionMessages(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<[AIMessageDTO]>
}

// DefaultAIAssistantRepository 默认 AI 助手数据仓库
// 核心职责：
// - 使用 MHBHTTPClient 调用后端 AI 接口
// - 使用 URLSession.bytes 解析 SSE 流式事件
struct DefaultAIAssistantRepository: AIAssistantRepository {
    private let client: MHBHTTPClient
    private let session: URLSession

    init(client: MHBHTTPClient = MHBHTTPClient.authenticated()) {
        self.client = client
        self.session = client.session
    }

    func openChatStream(
        message: String,
        selectedPetID: String?,
        surface: String,
        chatSessionID: String?
    ) -> AsyncThrowingStream<AIStreamEventDTO, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try buildStreamRequest(
                        message: message,
                        selectedPetID: selectedPetID,
                        surface: surface,
                        chatSessionID: chatSessionID
                    )
                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: MHBAPIError.invalidResponse)
                        return
                    }
                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: MHBAPIError.business(
                            code: "ai.stream_failed",
                            message: "流式连接失败",
                            statusCode: httpResponse.statusCode
                        ))
                        return
                    }

                    var currentEvent: String?
                    var currentData: String?

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        if line.hasPrefix("event:") {
                            currentEvent = line.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            currentData = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                        } else if line.isEmpty {
                            if let event = currentEvent, let data = currentData {
                                if let dto = AIStreamEventDecoder.decode(event: event, data: data) {
                                    continuation.yield(dto)
                                }
                            }
                            currentEvent = nil
                            currentData = nil
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func fetchChatSessions() async throws(MHBAPIError) -> MHBAPIResponse<[AIChatSessionDTO]> {
        try await client.get(path: "/api/v1/ai/chat-sessions")
    }

    func fetchSessionMessages(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<[AIMessageDTO]> {
        try await client.get(path: "/api/v1/ai/chat-sessions/\(sessionID)/messages")
    }

    // MARK: - Private

    private func buildStreamRequest(
        message: String,
        selectedPetID: String?,
        surface: String,
        chatSessionID: String?
    ) throws(MHBAPIError) -> URLRequest {
        let url = client.baseURL.appending(path: "/api/v1/ai/chat/stream")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        try client.prepareRequest(&request)

        let body = ChatStreamRequestBody(
            message: message,
            selectedPetID: selectedPetID,
            surface: surface,
            chatSessionID: chatSessionID
        )
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw .decoding(error.localizedDescription)
        }
        return request
    }
}

// ChatStreamRequestBody 流式聊天请求体
// 核心职责：
// - 承载用户消息和入口上下文
// - 不包含 actor_user_id（只从 token 注入）
private struct ChatStreamRequestBody: Encodable {
    let message: String
    let selectedPetID: String?
    let surface: String
    let chatSessionID: String?

    enum CodingKeys: String, CodingKey {
        case message
        case selectedPetID = "selected_pet_id"
        case surface
        case chatSessionID = "chat_session_id"
    }
}

// MockAIAssistantRepository 测试用 AI 助手数据仓库
// 核心职责：
// - 提供可控的流式事件序列和历史数据
// - 让 Store 测试不依赖网络
final class MockAIAssistantRepository: AIAssistantRepository {
    var streamEvents: [AIStreamEventDTO]
    var sessions: [AIChatSessionDTO]
    var messages: [AIMessageDTO]

    init(
        streamEvents: [AIStreamEventDTO] = [],
        sessions: [AIChatSessionDTO] = [],
        messages: [AIMessageDTO] = []
    ) {
        self.streamEvents = streamEvents
        self.sessions = sessions
        self.messages = messages
    }

    func openChatStream(
        message: String,
        selectedPetID: String?,
        surface: String,
        chatSessionID: String?
    ) -> AsyncThrowingStream<AIStreamEventDTO, Error> {
        AsyncThrowingStream { continuation in
            for event in streamEvents {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    func fetchChatSessions() async throws(MHBAPIError) -> MHBAPIResponse<[AIChatSessionDTO]> {
        MHBAPIResponse(success: true, code: "ai.sessions_loaded", message: "ok", data: sessions)
    }

    func fetchSessionMessages(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<[AIMessageDTO]> {
        MHBAPIResponse(success: true, code: "ai.messages_loaded", message: "ok", data: messages)
    }
}
