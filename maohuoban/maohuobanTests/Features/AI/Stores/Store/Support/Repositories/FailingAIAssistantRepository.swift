import Foundation
@testable import maohuoban

// FailingAIAssistantRepository 流式失败测试仓库
// 核心职责：
// - 模拟网络或 HTTP 错误发生在 message_started 之前
// - 验证 Store 能给用户追加本地网络失败提示
final class FailingAIAssistantRepository: AIAssistantRepository {
    func openChatStream(
        message: String,
        selectedPetID: String?,
        surface: String,
        chatSessionID: String?,
        entryContext: AIAssistantEntryContext,
        confirmationTaskID: String?
    ) -> AsyncThrowingStream<AIStreamEventDTO, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: MHBAPIError.business(
                code: "ai.stream_failed",
                message: "流式连接失败",
                statusCode: 503
            ))
        }
    }

    func fetchChatSessions() async throws(MHBAPIError) -> MHBAPIResponse<[AIChatSessionDTO]> {
        MHBAPIResponse(success: true, code: "ai.sessions_loaded", message: "ok", data: [])
    }

    func activateAbnormalEpisodeSession(
        abnormalEpisodeID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionDTO> {
        throw .business(
            code: "ai.unsupported_action",
            message: "当前测试仓库不支持激活异常追踪会话",
            statusCode: 400
        )
    }

    func fetchSessionMessages(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<[AIMessageDTO]> {
        MHBAPIResponse(success: true, code: "ai.messages_loaded", message: "ok", data: [])
    }

    func renameChatSession(
        sessionID: String,
        title: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        throw .business(
            code: "ai.unsupported_action",
            message: "当前测试仓库不支持重命名",
            statusCode: 400
        )
    }

    func setChatSessionPinned(
        sessionID: String,
        isPinned: Bool
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        throw .business(
            code: "ai.unsupported_action",
            message: "当前测试仓库不支持置顶",
            statusCode: 400
        )
    }

    func deleteChatSession(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        throw .business(
            code: "ai.unsupported_action",
            message: "当前测试仓库不支持删除",
            statusCode: 400
        )
    }

    func confirmProposedAction(
        _ action: AIAssistantProposedAction
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIAssistantActionConfirmationResultDTO> {
        throw .business(
            code: "ai.unsupported_action",
            message: "当前建议动作暂不支持确认",
            statusCode: 400
        )
    }

    func rejectConfirmationTask(
        taskID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIConfirmationTaskMutationResultDTO> {
        throw .business(
            code: "ai.unsupported_action",
            message: "当前测试仓库不支持取消确认任务",
            statusCode: 400
        )
    }
}
