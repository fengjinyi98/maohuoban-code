import Foundation

// FoodInventoryConsumeOneResult 食品资产消耗确认结果
// 核心职责：
// - 承载后端确认一个包装单位已吃完后的结果
// - 提供更新后的库存、周期事实和 toast 文案
struct FoodInventoryConsumeOneResult: Decodable, Equatable {
    let item: FoodInventoryItem
    let consumptionCycle: FoodInventoryConsumptionCycle
    let message: String

    enum CodingKeys: String, CodingKey {
        case item
        case consumptionCycle = "consumption_cycle"
        case message
    }
}
