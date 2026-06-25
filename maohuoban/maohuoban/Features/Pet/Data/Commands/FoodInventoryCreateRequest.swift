import Foundation

// FoodInventoryCreateRequest 创建食品资产请求体
// 核心职责：
// - 承载创建储物柜食品资产的后端请求字段
struct FoodInventoryCreateRequest: Encodable {
    let name: String
    let brand: String?
    let category: String
    let inventory_status: String
    let quantity: Int
    let unit: String?
    let spec: String?
    let expiry_date: String?
    let note: String?
}
