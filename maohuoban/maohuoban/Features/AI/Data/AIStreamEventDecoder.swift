import Foundation

// AIStreamEventDecoder SSE 事件解码器
// 核心职责：
// - 根据 SSE event 名称解码 JSON data 为 AIStreamEventDTO
// - 忽略前端不关注的事件类型
enum AIStreamEventDecoder {
    static func decode(event: String, data: String) -> AIStreamEventDTO? {
        guard let jsonData = data.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()

        switch event {
        case "message_started":
            guard let payload = try? decoder.decode(AIStreamMessageStartedPayload.self, from: jsonData) else {
                return nil
            }
            return .messageStarted(chatSessionID: payload.chatSessionID, messageID: payload.messageID, title: payload.title)
        case "delta", "answer_delta":
            guard let payload = try? decoder.decode(AIStreamDeltaPayload.self, from: jsonData) else {
                return nil
            }
            return .delta(text: payload.text)
        case "content_block_delta":
            guard let payload = try? decoder.decode(AIStreamContentBlockDeltaPayload.self, from: jsonData) else {
                return nil
            }
            return .contentBlockDelta(contentBlocks: payload.contentBlocks)
        case "citation":
            guard let payload = try? decoder.decode(AIStreamCitationPayload.self, from: jsonData) else { return nil }
            return .citation(reference: payload.citation.reference)
        case "tool_call":
            return nil
        case "agent_activity":
            guard let payload = try? decoder.decode(AIStreamAgentActivityPayload.self, from: jsonData) else { return nil }
            return .agentActivity(displayText: payload.displayText, status: payload.status)
        case "execution_trace_started":
            guard let payload = try? decoder.decode(AIStreamAgentActivityPayload.self, from: jsonData) else { return nil }
            return .agentActivity(displayText: payload.displayText, status: "started")
        case "execution_trace_completed":
            guard let payload = try? decoder.decode(AIStreamAgentActivityPayload.self, from: jsonData) else { return nil }
            return .agentActivity(displayText: payload.displayText, status: payload.status)
        case "confirmation_task":
            guard let payload = try? decoder.decode(AIStreamConfirmationTaskPayload.self, from: jsonData) else { return nil }
            return .confirmationTask(
                taskID: payload.taskID,
                questionText: payload.questionText,
                preview: payload.preview,
                actions: payload.actions
            )
        case "message_completed", "answer_completed":
            guard let payload = try? decoder.decode(AIStreamMessageCompletedPayload.self, from: jsonData) else {
                return nil
            }
            let references = payload.citations?.map(\.reference) ?? []
            let chips = references.map(\.label)
            return .messageCompleted(
                messageID: payload.messageID,
                finalText: payload.finalText,
                referenceChips: chips,
                references: references,
                contentBlocks: payload.contentBlocks ?? []
            )
        case "proposed_action":
            guard let payload = try? decoder.decode(AIStreamProposedActionPayload.self, from: jsonData) else { return nil }
            return .proposedAction(action: payload.action)
        case "error":
            guard let payload = try? decoder.decode(AIStreamErrorPayload.self, from: jsonData) else { return nil }
            return .error(
                code: payload.code,
                message: payload.message,
                retryable: payload.retryable,
                safeFallbackText: payload.safeFallbackText
            )
        default:
            return nil
        }
    }
}
