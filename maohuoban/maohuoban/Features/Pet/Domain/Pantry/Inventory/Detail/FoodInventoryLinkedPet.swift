import Foundation

// FoodInventoryLinkedPet 物品关联宠物
// 核心职责：
// - 表达物品与宠物的事实关联
// - 展示关联来源和宠物头像
struct FoodInventoryLinkedPet: Decodable, Equatable, Identifiable {
    let petID: String
    let petName: String
    let avatarAssetID: String?
    let avatarURL: String?
    let source: String

    var id: String { petID }

    enum CodingKeys: String, CodingKey {
        case petID = "pet_id"
        case petName = "pet_name"
        case avatarAssetID = "avatar_asset_id"
        case avatarURL = "avatar_url"
        case source
    }
}
