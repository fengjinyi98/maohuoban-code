import Foundation

// FoodInventoryRestoreRequest 恢复食品资产请求体
// 核心职责：
// - 提交归档资产恢复后的库存状态
// - 对齐后端 restore 接口字段契约
struct FoodInventoryRestoreRequest: Encodable {
    let inventory_status: String
}
