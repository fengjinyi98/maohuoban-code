import Foundation

// FoodInventoryConsumptionCycle 食品资产消耗周期
// 核心职责：
// - 对齐后端用户确认消耗完成事实
// - 为前端展示和后续分析扩展保留周期锚点
struct FoodInventoryConsumptionCycle: Decodable, Equatable {
    let id: String
    let foodItemID: String
    let scopeType: String
    let scopeID: String
    let confirmedByUserID: String
    let sequenceNo: Int
    let consumedQuantity: Int
    let packageWeightGrams: Int?
    let packageUnit: String?
    let confirmedAt: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case foodItemID = "food_item_id"
        case scopeType = "scope_type"
        case scopeID = "scope_id"
        case confirmedByUserID = "confirmed_by_user_id"
        case sequenceNo = "sequence_no"
        case consumedQuantity = "consumed_quantity"
        case packageWeightGrams = "package_weight_grams"
        case packageUnit = "package_unit"
        case confirmedAt = "confirmed_at"
        case createdAt = "created_at"
    }
}
