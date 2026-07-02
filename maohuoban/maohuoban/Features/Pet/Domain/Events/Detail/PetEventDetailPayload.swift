import Foundation

// PetEventDetailPayload 宠物事件详情载荷
// 核心职责：
// - 承载后端 event_payload 中已知的异常追踪字段
// - 使用宽松解码，未知 key 自动忽略，缺失字段返回 nil
struct PetEventDetailPayload: Decodable, Equatable {
    let symptomKinds: [String]?
    let severity: String?
    let symptomDetails: [String]?
    let note: String?
    let episodeID: String?

    enum CodingKeys: String, CodingKey {
        case symptomKinds = "symptom_kinds"
        case severity
        case symptomDetails = "symptom_details"
        case note
        case episodeID = "episode_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symptomKinds = try container.decodeIfPresent([String].self, forKey: .symptomKinds)
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
        symptomDetails = try container.decodeIfPresent([String].self, forKey: .symptomDetails)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        episodeID = try container.decodeIfPresent(String.self, forKey: .episodeID)
    }
}
