import Foundation

// PetTimelineEntry 宠物统一时间线条目
// 核心职责：
// - 表达真实宠物事件和生命周期事实的共同字段
// - 为首页摘要和完整记录列表提供同源读模型
struct PetTimelineEntry: Decodable, Equatable, Identifiable {
    let id: String
    let petID: String
    let kind: PetEventKind
    let subkind: String?
    let title: String
    let summary: String?
    let visibility: PetEventVisibility
    let occurredAt: String
    let recordRevision: Int
    let source: PetTimelineEntrySource
    let eventPayload: PetEventDetailPayload?

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
        case source
        case eventPayload = "event_payload"
    }
}
