import Foundation

// AIStreamEventDTO AI 流式事件 DTO
// 核心职责：
// - 表达后端 SSE 事件的稳定前端模型
// - 屏蔽后端枚举序列化差异，iOS 只消费自家事件协议
enum AIStreamEventDTO {
    case messageStarted(chatSessionID: UUID, messageID: UUID, title: String)
    case toolCall(toolName: String, status: String, citationCount: Int)
    case agentActivity(displayText: String, status: String)
    case confirmationTask(taskID: UUID, questionText: String)
    case delta(text: String)
    case messageCompleted(messageID: UUID, finalText: String, referenceChips: [String])
    case proposedAction(action: AIProposedActionDTO)
    case error(code: String, message: String, retryable: Bool, safeFallbackText: String?)
}
