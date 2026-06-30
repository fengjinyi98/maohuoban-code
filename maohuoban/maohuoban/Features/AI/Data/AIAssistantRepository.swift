import Foundation
import MaohuobanDiagnostics

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
    func renameChatSession(
        sessionID: String,
        title: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO>
    func setChatSessionPinned(
        sessionID: String,
        isPinned: Bool
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO>
    func deleteChatSession(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO>
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
                    mhbTempFrontendLog(
                        "stage=repo.stream.start message_len=\(message.count) selected_pet_present=\(selectedPetID != nil) chat_session_present=\(chatSessionID != nil) surface=\(surface)"
                    )
                    await AIAssistantDiagnostics.recordStreamRequestStarted(
                        surface: surface,
                        selectedPetID: selectedPetID,
                        chatSessionID: chatSessionID
                    )
                    let request = try buildStreamRequest(
                        message: message,
                        selectedPetID: selectedPetID,
                        surface: surface,
                        chatSessionID: chatSessionID
                    )
                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        mhbTempFrontendLog("stage=repo.stream.invalid_response")
                        continuation.finish(throwing: MHBAPIError.invalidResponse)
                        return
                    }
                    mhbTempFrontendLog(
                        "stage=repo.stream.opened status=\(httpResponse.statusCode)"
                    )
                    await AIAssistantDiagnostics.recordStreamResponseOpened(statusCode: httpResponse.statusCode)
                    guard httpResponse.statusCode == 200 else {
                        mhbTempFrontendLog(
                            "stage=repo.stream.non_200 status=\(httpResponse.statusCode)"
                        )
                        continuation.finish(throwing: MHBAPIError.business(
                            code: "ai.stream_failed",
                            message: "流式连接失败",
                            statusCode: httpResponse.statusCode
                        ))
                        return
                    }

                    var parser = AIStreamEventParser()

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        for parsedEvent in parser.consumeLine(line) {
                            await AIAssistantDiagnostics.recordStreamEventReceived(
                                eventName: parsedEvent.eventName,
                                event: parsedEvent.event
                            )
                            mhbTempFrontendLog(
                                "stage=repo.sse.event event_name=\(parsedEvent.eventName) decoded=\(parsedEvent.event != nil) data_len=\(parsedEvent.data.count) summary=\(parsedEvent.event?.mhbTempSummary ?? "nil")"
                            )
                            if let event = parsedEvent.event {
                                continuation.yield(event)
                            }
                        }
                    }

                    for parsedEvent in parser.finish() {
                        await AIAssistantDiagnostics.recordStreamEventReceived(
                            eventName: parsedEvent.eventName,
                            event: parsedEvent.event
                        )
                        mhbTempFrontendLog(
                            "stage=repo.sse.finish_event event_name=\(parsedEvent.eventName) decoded=\(parsedEvent.event != nil) data_len=\(parsedEvent.data.count) summary=\(parsedEvent.event?.mhbTempSummary ?? "nil")"
                        )
                        if let event = parsedEvent.event {
                            continuation.yield(event)
                        }
                    }

                    mhbTempFrontendLog("stage=repo.stream.finish")
                    continuation.finish()
                } catch {
                    mhbTempFrontendLog(
                        "stage=repo.stream.catch error_type=\(String(describing: type(of: error)))"
                    )
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

    func renameChatSession(
        sessionID: String,
        title: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        try await client.patch(
            path: "/api/v1/ai/chat-sessions/\(sessionID)/title",
            body: AIChatSessionRenameRequestBody(title: title)
        )
    }

    func setChatSessionPinned(
        sessionID: String,
        isPinned: Bool
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        try await client.patch(
            path: "/api/v1/ai/chat-sessions/\(sessionID)/pin",
            body: AIChatSessionPinRequestBody(isPinned: isPinned)
        )
    }

    func deleteChatSession(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        try await client.delete(
            path: "/api/v1/ai/chat-sessions/\(sessionID)",
            body: AIChatSessionEmptyRequestBody()
        )
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
            let bodyText = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "<invalid-utf8>"
            mhbTempFrontendLog(
                "stage=repo.request.body url=\(url.absoluteString) body=\(bodyText)"
            )
        } catch {
            throw .decoding(error.localizedDescription)
        }
        return request
    }
}

// MHB_TEMP_FRONTEND_LOG: AgentFallbackRegression 临时前端日志，确认修复后删除。
private func mhbTempFrontendLog(_ message: String) {
    print("[DEBUG:AgentFallbackRegression] \(message)")
}

extension AIStreamEventDTO {
    var mhbTempSummary: String {
        switch self {
        case .messageStarted(let chatSessionID, let messageID, let title):
            return "message_started chat_session_id=\(chatSessionID) message_id=\(messageID) title_len=\(title.count)"
        case .agentActivity(_, let status):
            return "agent_activity status=\(status)"
        case .confirmationTask:
            return "confirmation_task"
        case .delta(let text):
            return "delta chars=\(text.count) trimmed_empty=\(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)"
        case .citation(let label):
            return "citation label_len=\(label.count)"
        case .messageCompleted(let messageID, let finalText, let referenceChips):
            return "message_completed message_id=\(messageID) final_chars=\(finalText.count) final_trimmed_empty=\(finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) chips=\(referenceChips.count)"
        case .proposedAction:
            return "proposed_action"
        case .error(let code, _, let retryable, let safeFallbackText):
            return "error code=\(code) retryable=\(retryable) safe_present=\(safeFallbackText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)"
        }
    }
}

// AIChatSessionRenameRequestBody AI 会话重命名请求体
// 核心职责：
// - 承载用户输入的新会话标题
// - 保持字段命名与后端契约一致
private struct AIChatSessionRenameRequestBody: Encodable {
    let title: String
}

// AIChatSessionPinRequestBody AI 会话置顶请求体
// 核心职责：
// - 承载目标置顶状态
// - 对齐后端 is_pinned 字段
private struct AIChatSessionPinRequestBody: Encodable {
    let isPinned: Bool

    enum CodingKeys: String, CodingKey {
        case isPinned = "is_pinned"
    }
}

// AIChatSessionEmptyRequestBody AI 会话空请求体
// 核心职责：
// - 复用 JSON DELETE 发送路径
// - 承接只依赖路径和授权头的会话删除命令
private struct AIChatSessionEmptyRequestBody: Encodable {}

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
    var renamedSessionIDs: [String] = []
    var renamedTitles: [String] = []
    var pinnedSessionIDs: [String] = []
    var pinnedStates: [Bool] = []
    var deletedSessionIDs: [String] = []
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

    func renameChatSession(
        sessionID: String,
        title: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        renamedSessionIDs.append(sessionID)
        renamedTitles.append(title)
        return sessionMutationResponse(
            sessionID: sessionID,
            title: title,
            isPinned: currentPinnedState(sessionID: sessionID)
        )
    }

    func setChatSessionPinned(
        sessionID: String,
        isPinned: Bool
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        pinnedSessionIDs.append(sessionID)
        pinnedStates.append(isPinned)
        return sessionMutationResponse(
            sessionID: sessionID,
            title: currentTitle(sessionID: sessionID),
            isPinned: isPinned
        )
    }

    func deleteChatSession(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        deletedSessionIDs.append(sessionID)
        return sessionMutationResponse(
            sessionID: sessionID,
            title: currentTitle(sessionID: sessionID),
            isPinned: currentPinnedState(sessionID: sessionID)
        )
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

    private func sessionMutationResponse(
        sessionID: String,
        title: String,
        isPinned: Bool
    ) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        MHBAPIResponse(
            success: true,
            code: "ai.session_mutated",
            message: "ok",
            data: AIChatSessionMutationResultDTO(
                id: UUID(uuidString: sessionID) ?? UUID(),
                title: title,
                isPinned: isPinned
            )
        )
    }

    private func currentTitle(sessionID: String) -> String {
        sessions.first { $0.id.uuidString == sessionID }?.title ?? "会话"
    }

    private func currentPinnedState(sessionID: String) -> Bool {
        sessions.first { $0.id.uuidString == sessionID }?.isPinned ?? false
    }
}
