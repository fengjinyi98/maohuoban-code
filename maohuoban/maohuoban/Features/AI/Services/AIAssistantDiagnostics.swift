import Foundation
import MaohuobanDiagnostics

// AIAssistantDiagnostics AI 助手诊断事件记录器
// 核心职责：
// - 统一记录 AI 聊天、SSE 流和历史页面链路观测
// - 只写入脱敏后的 ID 前缀、计数、状态和错误分类
enum AIAssistantDiagnostics {
    static func recordChatSubmit(
        message: String,
        selectedPetID: String?,
        chatSessionID: String?
    ) async {
        await Diagnostics.track(
            "ai.chat.submit",
            properties: [
                "message_length_bucket": .string(lengthBucket(message.count)),
                "selected_pet_id_prefix": .string(prefix(selectedPetID)),
                "chat_session_id_prefix": .string(prefix(chatSessionID)),
                "has_selected_pet": .bool(selectedPetID?.isEmpty == false),
                "has_existing_chat_session": .bool(chatSessionID?.isEmpty == false),
            ]
        )
    }

    static func recordStreamRequestStarted(
        surface: String,
        selectedPetID: String?,
        chatSessionID: String?
    ) async {
        await Diagnostics.track(
            "ai.chat.stream.request.started",
            properties: [
                "surface": .string(surface),
                "selected_pet_id_prefix": .string(prefix(selectedPetID)),
                "chat_session_id_prefix": .string(prefix(chatSessionID)),
                "has_selected_pet": .bool(selectedPetID?.isEmpty == false),
                "has_existing_chat_session": .bool(chatSessionID?.isEmpty == false),
            ]
        )
    }

    static func recordStreamResponseOpened(statusCode: Int) async {
        await Diagnostics.track(
            "ai.chat.stream.response.opened",
            properties: [
                "status_code": .int(statusCode),
                "success": .bool(statusCode == 200),
            ]
        )
    }

    static func recordStreamEventReceived(eventName: String, event: AIStreamEventDTO?) async {
        var properties: DiagnosticProperties = [
            "event_name": .string(eventName),
            "decoded": .bool(event != nil),
        ]
        if let event {
            properties.merge(streamEventProperties(event)) { _, new in new }
        }
        await Diagnostics.track("ai.chat.stream.event.received", properties: properties)
    }

    static func recordStreamEventConsumed(
        _ event: AIStreamEventDTO,
        messageCount: Int,
        isStreaming: Bool
    ) async {
        var properties = streamEventProperties(event)
        properties["message_count"] = .int(messageCount)
        properties["is_streaming"] = .bool(isStreaming)
        await Diagnostics.track("ai.chat.stream.event.consumed", properties: properties)
    }

    static func recordStreamCompleted(
        messageCount: Int,
        assistantReplyPresent: Bool,
        isStreaming: Bool
    ) async {
        await Diagnostics.track(
            "ai.chat.stream.completed",
            properties: [
                "message_count": .int(messageCount),
                "assistant_reply_present": .bool(assistantReplyPresent),
                "is_streaming": .bool(isStreaming),
            ]
        )
    }

    static func recordAssistantFinalized(
        source: String,
        text: String,
        referenceChipCount: Int
    ) async {
        await Diagnostics.track(
            "ai.chat.assistant.finalized",
            properties: [
                "source": .string(source),
                "final_text_length_bucket": .string(lengthBucket(text.count)),
                "reference_chip_count": .int(referenceChipCount),
            ]
        )
    }

    static func recordStreamIssue(
        source: String,
        code: String,
        retryable: Bool?,
        hasStreamingPlaceholder: Bool
    ) async {
        var properties: DiagnosticProperties = [
            "source": .string(source),
            "code": .string(code),
            "has_streaming_placeholder": .bool(hasStreamingPlaceholder),
        ]
        if let retryable {
            properties["retryable"] = .bool(retryable)
        }
        await Diagnostics.track("ai.chat.stream.issue", properties: properties)
    }

    static func recordHistorySessionsLoaded(
        sessionCount: Int,
        pinnedCount: Int,
        petSnapshotCount: Int
    ) async {
        await Diagnostics.track(
            "ai.history.sessions.loaded",
            properties: [
                "session_count": .int(sessionCount),
                "pinned_count": .int(pinnedCount),
                "pet_snapshot_count": .int(petSnapshotCount),
            ]
        )
    }

    static func recordHistoryMessagesLoaded(sessionID: String, messageCount: Int) async {
        await Diagnostics.track(
            "ai.history.messages.loaded",
            properties: [
                "chat_session_id_prefix": .string(prefix(sessionID)),
                "message_count": .int(messageCount),
            ]
        )
    }

    static func recordHistoryMutationCompleted(
        action: String,
        sessionID: String,
        success: Bool
    ) async {
        await Diagnostics.track(
            "ai.history.mutation.completed",
            properties: [
                "action": .string(action),
                "chat_session_id_prefix": .string(prefix(sessionID)),
                "success": .bool(success),
            ]
        )
    }

    private static func streamEventProperties(_ event: AIStreamEventDTO) -> DiagnosticProperties {
        switch event {
        case .messageStarted(let chatSessionID, let messageID, _):
            [
                "event_name": .string("message_started"),
                "chat_session_id_prefix": .string(prefix(chatSessionID.uuidString)),
                "message_id_prefix": .string(prefix(messageID.uuidString)),
            ]
        case .agentActivity(let displayText, let status):
            [
                "event_name": .string("agent_activity"),
                "status": .string(status),
                "display_text_length_bucket": .string(lengthBucket(displayText.count)),
            ]
        case .confirmationTask(let taskID, let questionText):
            [
                "event_name": .string("confirmation_task"),
                "confirmation_task_id_prefix": .string(prefix(taskID.uuidString)),
                "question_length_bucket": .string(lengthBucket(questionText.count)),
            ]
        case .delta(let text):
            [
                "event_name": .string("delta"),
                "delta_length_bucket": .string(lengthBucket(text.count)),
            ]
        case .contentBlockDelta(let contentBlocks):
            [
                "event_name": .string("content_block_delta"),
                "content_block_count": .int(contentBlocks.count),
            ]
        case .citation(let reference):
            [
                "event_name": .string("citation"),
                "source_kind": .string(reference.sourceKind),
                "label_length_bucket": .string(lengthBucket(reference.label.count)),
            ]
        case .messageCompleted(let messageID, let finalText, let referenceChips, let references, let contentBlocks):
            [
                "event_name": .string("message_completed"),
                "message_id_prefix": .string(prefix(messageID.uuidString)),
                "final_text_length_bucket": .string(lengthBucket(finalText.count)),
                "reference_chip_count": .int(referenceChips.count),
                "reference_count": .int(references.count),
                "content_block_count": .int(contentBlocks.count),
            ]
        case .proposedAction(let action):
            [
                "event_name": .string("proposed_action"),
                "action_id_prefix": .string(prefix(action.id.uuidString)),
                "target_pet_id_prefix": .string(prefix(action.targetPetID.uuidString)),
                "action_kind": .string(action.actionKind),
                "risk_level": .string(action.riskLevel),
            ]
        case .error(let code, _, let retryable, let safeFallbackText):
            [
                "event_name": .string("error"),
                "error_code": .string(code),
                "retryable": .bool(retryable),
                "safe_text_present": .bool(safeFallbackText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false),
            ]
        }
    }

    private static func prefix(_ value: String?) -> String {
        guard let value else { return "" }
        return String(value.prefix(8))
    }

    private static func lengthBucket(_ count: Int) -> String {
        switch count {
        case 0:
            "0"
        case 1...32:
            "1_32"
        case 33...128:
            "33_128"
        case 129...512:
            "129_512"
        default:
            "513_plus"
        }
    }
}
