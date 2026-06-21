import Foundation

// AIAssistantMessage AI 助手消息模型
// 核心职责：
// - 表达用户、助手和系统边界提示消息
// - 携带前端可展示的引用标签和稳定身份
struct AIAssistantMessage: Identifiable, Hashable {
    enum Role: Hashable {
        case assistant
        case user
        case system
    }

    let id: UUID
    let role: Role
    let text: String
    let referenceChips: [String]

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        referenceChips: [String] = []
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.referenceChips = referenceChips
    }
}
