import Foundation

// PetEventDetail 宠物事件详情读模型
// 核心职责：
// - 承接宠物事件详情接口的稳定字段
// - 支持普通宠物事件和商家窝次事件共用详情页
struct PetEventDetail: Decodable, Equatable, Identifiable {
    let id: String
    let petID: String?
    let litterID: String?
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
        case litterID = "litter_id"
        case kind = "event_kind"
        case subkind = "event_subkind"
        case title
        case summary
        case visibility
        case occurredAt = "occurred_at"
        case recordRevision = "record_revision"
    }
}
