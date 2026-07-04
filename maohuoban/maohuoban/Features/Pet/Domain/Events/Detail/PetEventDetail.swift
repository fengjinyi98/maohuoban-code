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
    let eventPayload: PetEventDetailPayload?
    let attachmentAssets: [PetEventAttachmentAsset]

    init(
        id: String,
        petID: String?,
        litterID: String?,
        kind: PetEventKind,
        subkind: String?,
        title: String,
        summary: String?,
        visibility: PetEventVisibility,
        occurredAt: String,
        recordRevision: Int,
        eventPayload: PetEventDetailPayload?,
        attachmentAssets: [PetEventAttachmentAsset] = []
    ) {
        self.id = id
        self.petID = petID
        self.litterID = litterID
        self.kind = kind
        self.subkind = subkind
        self.title = title
        self.summary = summary
        self.visibility = visibility
        self.occurredAt = occurredAt
        self.recordRevision = recordRevision
        self.eventPayload = eventPayload
        self.attachmentAssets = attachmentAssets
    }

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
        case eventPayload = "event_payload"
        case attachmentAssets = "attachment_assets"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        petID = try container.decodeIfPresent(String.self, forKey: .petID)
        litterID = try container.decodeIfPresent(String.self, forKey: .litterID)
        kind = try container.decode(PetEventKind.self, forKey: .kind)
        subkind = try container.decodeIfPresent(String.self, forKey: .subkind)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        visibility = try container.decode(PetEventVisibility.self, forKey: .visibility)
        occurredAt = try container.decode(String.self, forKey: .occurredAt)
        recordRevision = try container.decode(Int.self, forKey: .recordRevision)
        eventPayload = try container.decodeIfPresent(PetEventDetailPayload.self, forKey: .eventPayload)
        attachmentAssets = try container.decodeIfPresent([PetEventAttachmentAsset].self, forKey: .attachmentAssets) ?? []
    }
}
