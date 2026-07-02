import Foundation

// AIAssistantSuggestedPrompt AI 助手建议问题
// 核心职责：
// - 为前端首屏提供可直接发送的宠物问题
// - 绑定展示图标与真实提交文本
struct AIAssistantSuggestedPrompt: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let prompt: String
    let systemImage: String
}
