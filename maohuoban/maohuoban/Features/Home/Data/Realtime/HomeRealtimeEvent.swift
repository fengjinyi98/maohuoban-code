import Foundation

// HomeRealtimeEvent 首页实时事件
// 核心职责：
// - 表达后端首页 SSE 下发的稳定刷新信号
// - 让首页 Store 只在相关事件到达后刷新读模型
struct HomeRealtimeEvent: Decodable, Equatable {
    let event: String
    let petID: String
    let hintID: String
    let kind: String
    let sourceRefType: String
    let sourceRefID: String
    let occurredAt: Date

    private enum CodingKeys: String, CodingKey {
        case event
        case petID = "pet_id"
        case hintID = "hint_id"
        case kind
        case sourceRefType = "source_ref_type"
        case sourceRefID = "source_ref_id"
        case occurredAt = "occurred_at"
    }

    init(
        event: String,
        petID: String,
        hintID: String,
        kind: String,
        sourceRefType: String,
        sourceRefID: String,
        occurredAt: Date
    ) {
        self.event = event
        self.petID = petID
        self.hintID = hintID
        self.kind = kind
        self.sourceRefType = sourceRefType
        self.sourceRefID = sourceRefID
        self.occurredAt = occurredAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        event = try container.decode(String.self, forKey: .event)
        petID = try container.decode(String.self, forKey: .petID)
        hintID = try container.decode(String.self, forKey: .hintID)
        kind = try container.decode(String.self, forKey: .kind)
        sourceRefType = try container.decode(String.self, forKey: .sourceRefType)
        sourceRefID = try container.decode(String.self, forKey: .sourceRefID)
        let occurredAtValue = try container.decode(String.self, forKey: .occurredAt)
        occurredAt = try HomeRealtimeISO8601DateParser.date(from: occurredAtValue)
    }
}
