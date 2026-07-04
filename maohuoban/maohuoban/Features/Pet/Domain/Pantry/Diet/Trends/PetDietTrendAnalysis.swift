import Foundation

// PetDietTrendAnalysis 饮食趋势分析结论
// 核心职责：
// - 对齐后端饮食趋势用户可读分析 DTO
// - 承载页面主展示结论和观察项
struct PetDietTrendAnalysis: Decodable, Equatable, Hashable {
    let headline: String
    let summary: String
    let observations: [String]
}
