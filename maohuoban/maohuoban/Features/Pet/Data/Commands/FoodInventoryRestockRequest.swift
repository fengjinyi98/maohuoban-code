import Foundation

// FoodInventoryRestockRequest 补库存请求体
// 核心职责：
// - 对齐后端补库存接口的增量字段
struct FoodInventoryRestockRequest: Encodable {
    let quantity_delta: Int
}
