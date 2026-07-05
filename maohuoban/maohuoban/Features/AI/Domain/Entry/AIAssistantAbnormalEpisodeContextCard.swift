import Foundation

// AIAssistantAbnormalEpisodeContextCard AI 异常追踪入口卡片
// 核心职责：
// - 承载从轻提醒进入 AI 会话时的异常上下文提示
// - 保持前端展示与后端 Agent 上下文字段一致
struct AIAssistantAbnormalEpisodeContextCard: Equatable {
    let episodeID: String
    let title: String
    let subtitle: String
    let petName: String
}
