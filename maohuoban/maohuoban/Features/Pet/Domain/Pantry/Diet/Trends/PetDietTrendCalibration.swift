import Foundation

// PetDietTrendCalibration 饮食趋势库存校准
// 核心职责：
// - 对齐后端饮食趋势库存校准 DTO
// - 表达克数估算是否具备库存闭环证据
struct PetDietTrendCalibration: Decodable, Equatable, Hashable {
    let confidence: String
    let gramsPerScore: Double?
    let dailyGrams: Double?
    let reason: String

    enum CodingKeys: String, CodingKey {
        case confidence
        case gramsPerScore = "grams_per_score"
        case dailyGrams = "daily_grams"
        case reason
    }
}
