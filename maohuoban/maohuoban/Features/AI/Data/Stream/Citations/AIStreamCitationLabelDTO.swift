import Foundation

// AIStreamCitationLabelDTO AI 流式引用 DTO
// 核心职责：
// - 解码 SSE citation 与 message_completed.citations
// - 映射为前端结构化引用模型
struct AIStreamCitationLabelDTO: Decodable {
    let sourceKind: String
    let sourceID: UUID
    let label: String

    enum CodingKeys: String, CodingKey {
        case sourceKind = "source_kind"
        case sourceID = "source_id"
        case label
    }

    var reference: AIAssistantReference {
        AIAssistantReference(
            sourceKind: sourceKind,
            sourceID: sourceID,
            label: label
        )
    }
}
