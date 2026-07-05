import Foundation

// AIAssistantQuoteBlock AI 引用语义块
// 核心职责：
// - 承载模型 Markdown 引用内容
// - 通过原生样式表达提示和确认问题
struct AIAssistantQuoteBlock: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let text: String
    let spans: [AIAssistantInlineTextSpan]
}
