import Foundation

// PetEventDraft 宠物事件创建草稿
// 核心职责：
// - 承载日常、健康等宠物记录输入
// - 统一映射到后端追加型事件接口
struct PetEventDraft: Encodable, Equatable {
    let kind: PetEventKind
    let subkind: String
    let title: String
    let summary: String
    let visibility: PetEventVisibility
    let occurredAt: String

    enum CodingKeys: String, CodingKey {
        case eventKind = "event_kind"
        case eventSubkind = "event_subkind"
        case title
        case summary
        case visibility
        case occurredAt = "occurred_at"
        case eventPayload = "event_payload"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .eventKind)
        try encodeOptionalText(subkind, key: .eventSubkind, into: &container)
        try container.encode(title.trimmingCharacters(in: .whitespacesAndNewlines), forKey: .title)
        try encodeOptionalText(summary, key: .summary, into: &container)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(occurredAt, forKey: .occurredAt)
        try container.encode([String: String](), forKey: .eventPayload)
    }

    private func encodeOptionalText(
        _ value: String,
        key: CodingKeys,
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedValue.isEmpty {
            try container.encodeNil(forKey: key)
        } else {
            try container.encode(trimmedValue, forKey: key)
        }
    }
}
