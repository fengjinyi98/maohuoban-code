import Foundation

// FoodInventoryFeedingTimelineEntry 物品喂食时间线
// 核心职责：
// - 表达某个物品参与过的喂食事件
// - 保留后端食品快照和份量文本
struct FoodInventoryFeedingTimelineEntry: Decodable, Equatable, Identifiable {
    let eventID: String
    let petID: String
    let petName: String
    let petSpecies: PetRecordPetSpecies
    let petSex: PetRecordPetSex
    let petAvatarAssetID: String?
    let petAvatarURL: String?
    let occurredAt: String
    let title: String
    let summary: String?
    let amountText: String
    let foodRole: String?
    let foodSnapshot: FoodInventoryFoodSnapshot?

    var id: String { eventID }

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case petID = "pet_id"
        case petName = "pet_name"
        case petSpecies = "pet_species"
        case petSex = "pet_sex"
        case petAvatarAssetID = "pet_avatar_asset_id"
        case petAvatarURL = "pet_avatar_url"
        case occurredAt = "occurred_at"
        case title
        case summary
        case amountText = "amount_text"
        case foodRole = "food_role"
        case foodSnapshot = "food_snapshot"
    }
}
