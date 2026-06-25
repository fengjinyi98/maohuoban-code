import Foundation

// FoodInventoryUpdateRequest 编辑食品资产请求体
// 核心职责：
// - 承载编辑储物柜食品资产的可选后端请求字段
struct FoodInventoryUpdateRequest: Encodable {
    let name: String?
    let brand: String?
    let category: String?
    let inventory_status: String?
    let quantity: Int?
    let unit: String?
    let spec: String?
    let expiry_date: String?
    let note: String?
}
