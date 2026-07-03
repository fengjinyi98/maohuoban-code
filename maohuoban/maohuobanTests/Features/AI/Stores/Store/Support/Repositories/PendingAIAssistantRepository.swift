import Foundation
@testable import maohuoban

// PendingAIAssistantRepository 挂起流式测试仓库
// 核心职责：
// - 模拟后端尚未返回首个 SSE 事件的等待窗口
// - 验证 Store 发起请求后立即提供输入反馈
final class PendingAIAssistantRepository: AIAssistantRepository {
    func openChatStream(
        message: String,
        selectedPetID: String?,
        surface: String,
        chatSessionID: String?
    ) -> AsyncThrowingStream<AIStreamEventDTO, Error> {
        AsyncThrowingStream { _ in }
    }

    func fetchChatSessions() async throws(MHBAPIError) -> MHBAPIResponse<[AIChatSessionDTO]> {
        MHBAPIResponse(success: true, code: "ai.sessions_loaded", message: "ok", data: [])
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
}
