import Foundation

// FoodInventoryConsumptionSummary 物品消耗统计
// 核心职责：
// - 展示喂食次数、跨度和模糊份量分布
// - 承载后端生成的物品维度消耗分析结论
struct FoodInventoryConsumptionSummary: Decodable, Equatable {
    let feedingCount: Int
    let firstFedAt: String?
    let lastFedAt: String?
    let activeDays: Int
    let amountDistribution: [FoodInventoryAmountDistributionItem]
    let headline: String
    let usageRhythm: String
    let portionStability: String
    let calibrationState: String
    let observations: [String]

    enum CodingKeys: String, CodingKey {
        case feedingCount = "feeding_count"
        case firstFedAt = "first_fed_at"
        case lastFedAt = "last_fed_at"
        case activeDays = "active_days"
        case amountDistribution = "amount_distribution"
        case headline
        case usageRhythm = "usage_rhythm"
        case portionStability = "portion_stability"
        case calibrationState = "calibration_state"
        case observations
    }
}
