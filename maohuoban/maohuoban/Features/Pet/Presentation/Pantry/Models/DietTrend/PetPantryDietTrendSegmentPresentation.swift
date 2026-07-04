import Foundation

// PetPantryDietTrendSegmentPresentation 饮食趋势分段展示模型
// 核心职责：
// - 承接后端分段 DTO 的展示字段
// - 为趋势条和图例提供稳定百分比文案
struct PetPantryDietTrendSegmentPresentation: Equatable, Identifiable {
    let category: String
    let title: String
    let percentage: Int
    let percentageText: String

    var id: String { category }
}
