import Foundation

// AIProposedActionDTO 建议动作 DTO
// 核心职责：
// - 解码后端 proposed_action SSE 事件中的动作载荷
// - 映射到前端 AIAssistantProposedAction
struct AIProposedActionDTO: Decodable {
    let id: UUID
    let actionKind: String
    let targetPetID: UUID
    let confirmText: String
    let riskLevel: String
    let payload: AIProposedActionPayloadDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case actionKind = "action_kind"
        case targetPetID = "target_pet_id"
        case confirmText = "confirm_text"
        case riskLevel = "risk_level"
        case payload
    }
}
