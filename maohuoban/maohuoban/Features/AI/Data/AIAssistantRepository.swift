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
                        continuation.finish(throwing: MHBAPIError.invalidResponse)
                        return
                    }
                    await AIAssistantDiagnostics.recordStreamResponseOpened(statusCode: httpResponse.statusCode)
                    guard httpResponse.statusCode == 200 else {
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
                        if let event = parsedEvent.event {
                            continuation.yield(event)
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
        } catch {
            throw .decoding(error.localizedDescription)
        }
        return request
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
