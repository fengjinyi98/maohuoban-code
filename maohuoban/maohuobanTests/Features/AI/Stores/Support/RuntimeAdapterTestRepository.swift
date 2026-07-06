import Foundation
@testable import maohuoban

// RuntimeAdapterTestRepository runtime adapter 测试仓库
// 核心职责：
// - 向 Store 提供指定 SSE 事件序列
// - 屏蔽历史和确认接口依赖
final class RuntimeAdapterTestRepository: AIAssistantRepository {
    private let streamEvents: [AIStreamEventDTO]

    init(streamEvents: [AIStreamEventDTO]) {
        self.streamEvents = streamEvents
    }

    func openChatStream(
        message: String,
        selectedPetID: String?,
        surface: String,
        chatSessionID: String?,
        entryContext: AIAssistantEntryContext
    ) -> AsyncThrowingStream<AIStreamEventDTO, Error> {
        AsyncThrowingStream { continuation in
            for event in streamEvents {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    func fetchChatSessions() async throws(MHBAPIError) -> MHBAPIResponse<[AIChatSessionDTO]> {
        MHBAPIResponse(success: true, code: "ai.sessions_loaded", message: "ok", data: [])
    }

    func activateAbnormalEpisodeSession(
        abnormalEpisodeID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionDTO> {
        throw .business(code: "ai.unsupported_action", message: "当前测试仓库不支持激活异常追踪会话", statusCode: 400)
    }

    func fetchSessionMessages(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<[AIMessageDTO]> {
        MHBAPIResponse(success: true, code: "ai.messages_loaded", message: "ok", data: [])
    }

    func renameChatSession(
        sessionID: String,
        title: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        throw .business(code: "ai.unsupported_action", message: "当前测试仓库不支持重命名", statusCode: 400)
    }

    func setChatSessionPinned(
        sessionID: String,
        isPinned: Bool
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        throw .business(code: "ai.unsupported_action", message: "当前测试仓库不支持置顶", statusCode: 400)
    }

    func deleteChatSession(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        throw .business(code: "ai.unsupported_action", message: "当前测试仓库不支持删除", statusCode: 400)
    }

    func confirmProposedAction(
        _ action: AIAssistantProposedAction
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIAssistantActionConfirmationResultDTO> {
        throw .business(code: "ai.unsupported_action", message: "当前建议动作暂不支持确认", statusCode: 400)
    }
}
