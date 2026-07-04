import SwiftUI
import MaohuobanDesignSystem

// PetDietTrendSegmentPresentation 宠物饮食趋势分段展示模型
// 核心职责：
// - 承载趋势条和图例渲染所需的窄字段
// - 为不同饮食品类提供稳定颜色映射
struct PetDietTrendSegmentPresentation: Identifiable {
    let id: String
    let title: String
    let percentage: Int
    let percentageText: String
    let color: Color

    init(segment: PetDietTrendSegment) {
        self.id = segment.category
        self.title = segment.title
        self.percentage = segment.percentage
        self.percentageText = "\(segment.percentage)%"
        self.color = Self.color(for: segment.category)
    }

    private static func color(for category: String) -> Color {
        switch category {
        case "main_food":
            return MHBTheme.ColorToken.primary.color
        case "wet_food":
            return .cyan
        case "treats":
            return .pink
        case "nutrition":
            return .green
        case "other":
            return .orange
        default:
            return MHBTheme.ColorToken.labelSecondary.color
        }
    }
}
