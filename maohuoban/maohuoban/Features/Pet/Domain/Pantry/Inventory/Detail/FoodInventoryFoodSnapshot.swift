import Foundation

// FoodInventoryFoodSnapshot 喂食食品快照
// 核心职责：
// - 展示喂食发生时刻的食品信息
// - 避免受后续物品编辑影响
struct FoodInventoryFoodSnapshot: Decodable, Equatable {
    let name: String
    let brand: String?
    let category: String
    let spec: String?
    let packageWeightGrams: Int?
    let packageCount: Int?
    let packageUnit: String?
    let coverAssetID: String?
    let coverURL: String?

    enum CodingKeys: String, CodingKey {
        case name
        case brand
        case category
        case spec
        case packageWeightGrams = "package_weight_grams"
        case packageCount = "package_count"
        case packageUnit = "package_unit"
        case coverAssetID = "cover_asset_id"
        case coverURL = "cover_url"
    }
}
