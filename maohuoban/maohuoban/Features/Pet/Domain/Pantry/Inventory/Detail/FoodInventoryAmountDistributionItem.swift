import Foundation

// FoodInventoryAmountDistributionItem 模糊份量分布项
// 核心职责：
// - 展示少一点、正常、多一点等份量选择的统计结果
// - 支持详情页绘制分布条
struct FoodInventoryAmountDistributionItem: Decodable, Equatable, Identifiable {
    let amountText: String
    let count: Int
    let ratio: Double

    var id: String { amountText }

    enum CodingKeys: String, CodingKey {
        case amountText = "amount_text"
        case count
        case ratio
    }
}
