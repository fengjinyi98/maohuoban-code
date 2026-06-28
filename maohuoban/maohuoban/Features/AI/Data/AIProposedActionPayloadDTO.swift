import Foundation

// AIProposedActionPayloadDTO 建议动作确认 payload DTO
// 核心职责：
// - 解码后端 proposed action 中的确认接口字段
// - 将 snake_case 字段转换为前端稳定模型
struct AIProposedActionPayloadDTO: Decodable {
    let foodItemID: UUID?
    let confirmedFactKind: String?
    let sourceQuestion: String?
    let deriveDietChange: Bool
    let deriveFeedingCorrection: Bool

    enum CodingKeys: String, CodingKey {
        case foodItemID = "food_item_id"
        case confirmedFactKind = "confirmed_fact_kind"
        case sourceQuestion = "source_question"
        case deriveDietChange = "derive_diet_change"
        case deriveFeedingCorrection = "derive_feeding_correction"
    }

    init(
        foodItemID: UUID?,
        confirmedFactKind: String?,
        sourceQuestion: String?,
        deriveDietChange: Bool,
        deriveFeedingCorrection: Bool
    ) {
        self.foodItemID = foodItemID
        self.confirmedFactKind = confirmedFactKind
        self.sourceQuestion = sourceQuestion
        self.deriveDietChange = deriveDietChange
        self.deriveFeedingCorrection = deriveFeedingCorrection
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        foodItemID = try container.decodeIfPresent(UUID.self, forKey: .foodItemID)
        confirmedFactKind = try container.decodeIfPresent(String.self, forKey: .confirmedFactKind)
        sourceQuestion = try container.decodeIfPresent(String.self, forKey: .sourceQuestion)
        deriveDietChange = try container.decodeIfPresent(Bool.self, forKey: .deriveDietChange) ?? false
        deriveFeedingCorrection = try container.decodeIfPresent(Bool.self, forKey: .deriveFeedingCorrection) ?? false
    }
}
