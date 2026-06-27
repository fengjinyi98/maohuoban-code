import Foundation

// AIAssistantProposedAction AI 助手建议动作
// 核心职责：
// - 表达需要用户确认的前端写操作意图
// - 携带后端确认接口所需的动作类型、目标宠物和 payload
struct AIAssistantProposedAction: Identifiable, Hashable {
    let id: String
    let actionKind: String
    let targetPetID: String
    let title: String
    let subtitle: String
    let confirmTitle: String
    let cancelTitle: String
    let systemImage: String
    let payload: AIAssistantProposedActionPayload?
}
