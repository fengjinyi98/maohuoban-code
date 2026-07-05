import Foundation

// FoodInventoryItemDetail 储物柜物品详情
// 核心职责：
// - 对齐后端食品资产详情读模型
// - 为物品详情页提供单一数据源
struct FoodInventoryItemDetail: Decodable, Equatable {
    let item: FoodInventoryItem
    let linkedPets: [FoodInventoryLinkedPet]
    let feedingTimeline: [FoodInventoryFeedingTimelineEntry]
    let consumptionSummary: FoodInventoryConsumptionSummary

    enum CodingKeys: String, CodingKey {
        case item
        case linkedPets = "linked_pets"
        case feedingTimeline = "feeding_timeline"
        case consumptionSummary = "consumption_summary"
    }
}
