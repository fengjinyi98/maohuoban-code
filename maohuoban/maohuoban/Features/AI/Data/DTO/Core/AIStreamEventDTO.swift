import Foundation

// AIStreamEventDTO AI 流式事件 DTO
// 核心职责：
// - 表达后端 SSE 事件的稳定前端模型
// - 屏蔽后端枚举序列化差异，iOS 只消费自家事件协议
enum AIStreamEventDTO {
    case messageStarted(chatSessionID: UUID, messageID: UUID, title: String)
    case agentActivity(displayText: String, status: String)
    case confirmationTask(taskID: UUID, questionText: String)
    case delta(text: String)
    case contentBlockDelta(contentBlocks: [AIAssistantContentBlock])
    case citation(reference: AIAssistantReference)
    case messageCompleted(
        messageID: UUID,
        finalText: String,
        referenceChips: [String],
        references: [AIAssistantReference],
        contentBlocks: [AIAssistantContentBlock] = []
    )
    case proposedAction(action: AIProposedActionDTO)
    case error(code: String, message: String, retryable: Bool, safeFallbackText: String?)
}
