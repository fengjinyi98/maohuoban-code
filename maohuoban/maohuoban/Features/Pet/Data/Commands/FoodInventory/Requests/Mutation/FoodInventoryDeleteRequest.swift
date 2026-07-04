import Foundation

// FoodInventoryDeleteRequest 移出储物柜请求体
// 核心职责：
// - 承载用户触发删除时的原因字段
struct FoodInventoryDeleteRequest: Encodable {
    let reason: String
}
