import Foundation

// AIAssistantTextBlock AI 文本语义块
// 核心职责：
// - 承载标题和段落等短文本内容
// - 保留稳定 id 以支持消息流 diff 和无障碍定位
struct AIAssistantTextBlock: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let text: String
}
