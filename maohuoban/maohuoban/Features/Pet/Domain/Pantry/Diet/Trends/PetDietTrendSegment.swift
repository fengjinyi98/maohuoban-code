import Foundation

// PetDietTrendSegment 饮食趋势分段
// 核心职责：
// - 对齐后端饮食趋势分段占比 DTO
// - 为首页趋势条提供分类、分数和百分比
struct PetDietTrendSegment: Decodable, Equatable, Hashable, Identifiable {
    let category: String
    let title: String
    let score: Double
    let percentage: Int
    let baselineScore: Double?
    let baselineSampleDays: Int
    let currentRatio: Double?
    let emaScore: Double?

    var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category
        case title
        case score
        case percentage
        case baselineScore = "baseline_score"
        case baselineSampleDays = "baseline_sample_days"
        case currentRatio = "current_ratio"
        case emaScore = "ema_score"
    }
}
