import Foundation

// AIAssistantInlineTextStyle AI 行内文本样式
// 核心职责：
// - 约束 AI 正文可以使用的局部样式
// - 为 SwiftUI 富文本渲染提供稳定枚举
enum AIAssistantInlineTextStyle: String, Decodable, Equatable, Hashable {
    case text
    case strong
}
