import Foundation

// FoodInventoryDeleteRequest 归档食品资产请求体
// 核心职责：
// - 承载用户触发归档时的原因字段
struct FoodInventoryDeleteRequest: Encodable {
    let reason: String
}
