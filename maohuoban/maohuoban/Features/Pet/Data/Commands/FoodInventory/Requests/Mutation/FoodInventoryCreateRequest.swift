import Foundation

// FoodInventoryCreateRequest 创建食品资产请求体
// 核心职责：
// - 承载创建储物柜食品资产的后端请求字段
struct FoodInventoryCreateRequest: Encodable {
    let name: String
    let brand: String?
    let category: String
    let quantity: Int
    let unit: String?
    let spec: String?
    let package_weight_grams: Int?
    let package_count: Int
    let package_unit: String?
    let production_date: String?
    let shelf_life_months: Int?
    let cover_asset_id: String?
    let note: String?
}
