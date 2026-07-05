import Foundation

// PetFoodSnapshot 喂食食品快照
// 核心职责：
// - 解码后端喂食事件中的食品快照
// - 允许品牌、规格和封面为空，保障历史喂食记录可展示
struct PetFoodSnapshot: Decodable, Equatable {
    let name: String
    let brand: String?
    let category: String
    let spec: String?
    let coverAssetID: String?
    let coverURL: String?

    enum CodingKeys: String, CodingKey {
        case name
        case brand
        case category
        case spec
        case coverAssetID = "cover_asset_id"
        case coverURL = "cover_url"
    }

    subscript(key: String) -> String? {
        switch key {
        case "name":
            name
        case "brand":
            brand
        case "category":
            category
        case "spec":
            spec
        case "cover_asset_id":
            coverAssetID
        case "cover_url":
            coverURL
        default:
            nil
        }
    }
}
