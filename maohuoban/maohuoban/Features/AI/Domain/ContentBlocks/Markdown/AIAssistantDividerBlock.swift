import Foundation

// AIAssistantDividerBlock AI 分割线语义块
// 核心职责：
// - 表达模型 Markdown 分割线的原生 UI 语义
// - 避免在正文中直接展示 `---` 标记
struct AIAssistantDividerBlock: Decodable, Equatable, Hashable, Identifiable {
    let id: String
}
