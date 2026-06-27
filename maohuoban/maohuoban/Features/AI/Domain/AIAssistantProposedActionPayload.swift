import Foundation

// AIAssistantProposedActionPayload 建议动作确认 payload
// 核心职责：
// - 承载饮食确认等动作的后端请求字段
// - 让 Store 不解析任意 JSON 结构
struct AIAssistantProposedActionPayload: Hashable {
    let foodItemID: String?
    let confirmedFactKind: String?
    let sourceQuestion: String?
    let deriveDietChange: Bool
    let deriveFeedingCorrection: Bool
}
