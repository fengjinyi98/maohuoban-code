import Foundation

// AIAssistantSectionHeadingBlock AI 标题语义块
// 核心职责：
// - 承载 AI 回复中的轻标题文本
// - 与正文段落的行内样式契约保持分离
struct AIAssistantSectionHeadingBlock: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let text: String
}
