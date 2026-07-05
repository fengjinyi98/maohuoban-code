import Foundation

// FoodInventoryConsumptionSummary 物品消耗统计
// 核心职责：
// - 展示喂食次数、跨度和模糊份量分布
// - 不承载克重估算和健康诊断结论
struct FoodInventoryConsumptionSummary: Decodable, Equatable {
    let feedingCount: Int
    let firstFedAt: String?
    let lastFedAt: String?
    let activeDays: Int
    let amountDistribution: [FoodInventoryAmountDistributionItem]

    enum CodingKeys: String, CodingKey {
        case feedingCount = "feeding_count"
        case firstFedAt = "first_fed_at"
        case lastFedAt = "last_fed_at"
        case activeDays = "active_days"
        case amountDistribution = "amount_distribution"
    }
}
