import Foundation

// PetDietTrendSegment 饮食趋势分段
// 核心职责：
// - 对齐后端饮食趋势分段占比 DTO
// - 为储物柜趋势条提供分类、分数和百分比
struct PetDietTrendSegment: Decodable, Equatable, Identifiable {
    let category: String
    let title: String
    let score: Double
    let percentage: Int

    var id: String { category }
}
