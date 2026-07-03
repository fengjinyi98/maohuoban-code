import Foundation

// AIChatSessionRenameRequestBody AI 会话重命名请求体
// 核心职责：
// - 承载用户输入的新会话标题
// - 保持字段命名与后端契约一致
struct AIChatSessionRenameRequestBody: Encodable {
    let title: String
}
