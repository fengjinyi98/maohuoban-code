import Foundation

// AIAssistantProposedAction AI 助手建议动作
// 核心职责：
// - 表达需要用户确认的前端写操作意图
// - 让写入动作在后端接入前保持明确确认边界
struct AIAssistantProposedAction: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let confirmTitle: String
    let cancelTitle: String
    let systemImage: String
}
