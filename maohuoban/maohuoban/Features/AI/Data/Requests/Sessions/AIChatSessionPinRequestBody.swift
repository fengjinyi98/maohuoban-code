import Foundation

// AIChatSessionPinRequestBody AI 会话置顶请求体
// 核心职责：
// - 承载目标置顶状态
// - 对齐后端 is_pinned 字段
struct AIChatSessionPinRequestBody: Encodable {
    let isPinned: Bool

    enum CodingKeys: String, CodingKey {
        case isPinned = "is_pinned"
    }
}
