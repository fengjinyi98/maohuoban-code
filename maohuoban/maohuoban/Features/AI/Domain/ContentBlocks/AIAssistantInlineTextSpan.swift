import Foundation

// AIAssistantInlineTextSpan AI 行内文本片段
// 核心职责：
// - 承载正文段落内受控的局部样式
// - 避免前端直接渲染 Markdown 原始标记
struct AIAssistantInlineTextSpan: Decodable, Equatable, Hashable {
    let text: String
    let style: AIAssistantInlineTextStyle
}
