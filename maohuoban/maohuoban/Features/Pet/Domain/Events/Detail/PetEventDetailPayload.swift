import Foundation

// PetEventDetailPayload 宠物事件详情载荷
// 核心职责：
// - 承载后端 event_payload 中已知的异常追踪和喂食字段
// - 使用宽松解码，未知 key 自动忽略，缺失字段返回 nil
struct PetEventDetailPayload: Decodable, Equatable {
    let foodItemID: String?
    let foodRole: String?
    let amountText: String?
    let foodSnapshot: FoodSnapshot?
    let isDefaultFood: Bool?
    let symptomKinds: [String]?
    let severity: String?
    let symptomDetails: [String]?
    let note: String?
    let episodeID: String?
    let attachmentAssetIDs: [String]?

    // FoodSnapshot 喂食食品快照
    // 核心职责：
    // - 保留喂食发生时的食品名称、品牌、分类和规格
    // - 避免详情页依赖后续可能变化的储物柜物品状态
    struct FoodSnapshot: Decodable, Equatable {
        let name: String
        let brand: String?
        let category: String?
        let spec: String?
    }

    enum CodingKeys: String, CodingKey {
        case foodItemID = "food_item_id"
        case foodRole = "food_role"
        case amountText = "amount_text"
        case foodSnapshot = "food_snapshot"
        case isDefaultFood = "is_default_food"
        case symptomKinds = "symptom_kinds"
        case severity
        case symptomDetails = "symptom_details"
        case note
        case episodeID = "episode_id"
        case attachmentAssetIDs = "attachment_asset_ids"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        foodItemID = try container.decodeIfPresent(String.self, forKey: .foodItemID)
        foodRole = try container.decodeIfPresent(String.self, forKey: .foodRole)
        amountText = try container.decodeIfPresent(String.self, forKey: .amountText)
        foodSnapshot = try container.decodeIfPresent(FoodSnapshot.self, forKey: .foodSnapshot)
        isDefaultFood = try container.decodeIfPresent(Bool.self, forKey: .isDefaultFood)
        symptomKinds = try container.decodeIfPresent([String].self, forKey: .symptomKinds)
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
        symptomDetails = try container.decodeIfPresent([String].self, forKey: .symptomDetails)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        episodeID = try container.decodeIfPresent(String.self, forKey: .episodeID)
        attachmentAssetIDs = try container.decodeIfPresent([String].self, forKey: .attachmentAssetIDs)
    }
}
