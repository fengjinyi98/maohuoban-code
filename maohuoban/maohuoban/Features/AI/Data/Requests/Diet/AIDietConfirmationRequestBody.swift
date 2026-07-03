import Foundation

// AIDietConfirmationRequestBody AI 饮食确认请求体
// 核心职责：
// - 承载 pending action 确认接口所需字段
// - 保持前端字段命名和后端 snake_case 契约一致
struct AIDietConfirmationRequestBody: Encodable {
    let foodItemID: String
    let confirmedFactKind: String
    let sourceQuestion: String
    let deriveDietChange: Bool
    let deriveFeedingCorrection: Bool

    enum CodingKeys: String, CodingKey {
        case foodItemID = "food_item_id"
        case confirmedFactKind = "confirmed_fact_kind"
        case sourceQuestion = "source_question"
        case deriveDietChange = "derive_diet_change"
        case deriveFeedingCorrection = "derive_feeding_correction"
    }
}
