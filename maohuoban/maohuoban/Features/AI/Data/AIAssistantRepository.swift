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
    func confirmProposedAction(
        _ action: AIAssistantProposedAction
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIAssistantActionConfirmationResultDTO>
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

    func confirmProposedAction(
        _ action: AIAssistantProposedAction
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIAssistantActionConfirmationResultDTO> {
        guard action.actionKind == "diet_change_confirmation" || action.actionKind == "feeding_correction" else {
            throw .business(
                code: "ai.unsupported_action",
                message: "当前建议动作暂不支持确认",
                statusCode: 400
            )
        }
        guard let payload = action.payload,
              let foodItemID = payload.foodItemID,
              let confirmedFactKind = payload.confirmedFactKind,
              let sourceQuestion = payload.sourceQuestion else {
            throw .business(
                code: "ai.action_payload_missing",
                message: "建议动作缺少确认所需信息",
                statusCode: 400
            )
        }

        let body = AIDietConfirmationRequestBody(
            foodItemID: foodItemID,
            confirmedFactKind: confirmedFactKind,
            sourceQuestion: sourceQuestion,
            deriveDietChange: payload.deriveDietChange,
            deriveFeedingCorrection: payload.deriveFeedingCorrection
        )
        return try await client.post(
            path: "/api/v1/pets/\(action.targetPetID)/diet-confirmations",
            body: body
        )
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

// AIDietConfirmationRequestBody AI 饮食确认请求体
// 核心职责：
// - 承载 pending action 确认接口所需字段
// - 保持前端字段命名和后端 snake_case 契约一致
private struct AIDietConfirmationRequestBody: Encodable {
    let foodItemID: String
    let confirmedFactKind: String
    let sourceQuestion: String
    let deriveDietChange: Bool
    let deriveFeedingCorrection: Bool

    enum CodingKeys: String, CodingKey {
        case foodItemID = "food_item_id"
        case confirmedFactKind = "confirmed_fact_kind"
        case sourceQuestion = "source_question"
        case deriveDietChange = "derive_diet_change"
        case deriveFeedingCorrection = "derive_feeding_correction"
    }
}

// AIAssistantActionConfirmationResultDTO 建议动作确认结果 DTO
// 核心职责：
// - 解码后端饮食确认接口返回的事件与配置 ID
// - 让 Store 只关心确认是否成功
struct AIAssistantActionConfirmationResultDTO: Decodable, Equatable {
    let confirmedEventID: UUID
    let assignmentID: UUID?
    let correctionEventID: UUID?

    enum CodingKeys: String, CodingKey {
        case confirmedEventID = "confirmed_event_id"
        case assignmentID = "assignment_id"
        case correctionEventID = "correction_event_id"
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
    var confirmedActionIDs: [String] = []
    var confirmResult: Result<MHBAPIResponse<AIAssistantActionConfirmationResultDTO>, MHBAPIError>

    init(
        streamEvents: [AIStreamEventDTO] = [],
        sessions: [AIChatSessionDTO] = [],
        messages: [AIMessageDTO] = [],
        confirmResult: Result<MHBAPIResponse<AIAssistantActionConfirmationResultDTO>, MHBAPIError> = .success(
            MHBAPIResponse(
                success: true,
                code: "pet.diet_candidate_confirmed",
                message: "饮食候选已确认",
                data: AIAssistantActionConfirmationResultDTO(
                    confirmedEventID: UUID(),
                    assignmentID: nil,
                    correctionEventID: nil
                )
            )
        )
    ) {
        self.streamEvents = streamEvents
        self.sessions = sessions
        self.messages = messages
        self.confirmResult = confirmResult
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

    func confirmProposedAction(
        _ action: AIAssistantProposedAction
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIAssistantActionConfirmationResultDTO> {
        confirmedActionIDs.append(action.id)
        switch confirmResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}
