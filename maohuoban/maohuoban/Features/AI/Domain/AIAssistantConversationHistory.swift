import Foundation

// AIAssistantConversationHistory AI 对话历史会话
// 核心职责：
// - 为对话记录页面提供前端 mock 会话数据
// - 携带选中后回填聊天页的消息列表
struct AIAssistantConversationHistory: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let messages: [AIAssistantMessage]
}
