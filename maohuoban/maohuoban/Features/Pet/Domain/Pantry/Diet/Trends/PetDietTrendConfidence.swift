import Foundation

// PetDietTrendConfidence 饮食趋势置信度
// 核心职责：
// - 对齐后端饮食趋势置信度 DTO
// - 承载前端可展示的可信依据
struct PetDietTrendConfidence: Decodable, Equatable, Hashable {
    let level: String
    let score: Double
    let basis: [String]
}
