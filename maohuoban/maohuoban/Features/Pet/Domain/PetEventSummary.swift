import Foundation

// PetEventSummary 宠物事件创建响应摘要
// 核心职责：
// - 承接后端追加事件后的稳定字段
// - 为表单成功态和时间线刷新提供事件 ID
struct PetEventSummary: Decodable, Equatable, Identifiable {
    let id: String
    let petID: String
    let kind: PetEventKind
    let subkind: String?
    let title: String
    let summary: String?
    let visibility: PetEventVisibility
    let occurredAt: String
    let recordRevision: Int

    enum CodingKeys: String, CodingKey {
        case id
        case petID = "pet_id"
        case kind = "event_kind"
        case subkind = "event_subkind"
        case title
        case summary
        case visibility
        case occurredAt = "occurred_at"
        case recordRevision = "record_revision"
    }
}
