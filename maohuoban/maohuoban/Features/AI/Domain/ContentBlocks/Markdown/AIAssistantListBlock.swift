import Foundation

// AIAssistantListBlock AI 列表语义块
// 核心职责：
// - 承载模型 Markdown 列表项
// - 为前端提供稳定列表行渲染输入
struct AIAssistantListBlock: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let items: [AIAssistantRichTextLineBlock]
}
