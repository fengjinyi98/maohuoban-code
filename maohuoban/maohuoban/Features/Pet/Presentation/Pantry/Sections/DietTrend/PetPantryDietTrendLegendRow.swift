import SwiftUI
import MaohuobanDesignSystem

// PetPantryDietTrendLegendRow 饮食趋势图例行
// 核心职责：
// - 展示单个饮食品类名称和百分比
// - 用稳定色点对应分段条颜色
struct PetPantryDietTrendLegendRow: View {
    let segment: PetPantryDietTrendSegmentPresentation

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Circle()
                .fill(color(for: segment.category))
                .frame(width: 8, height: 8)

            Text(segment.title)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineLimit(1)

            Spacer(minLength: MHBTheme.Spacing.s2)

            Text(segment.percentageText)
                .font(MHBTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
    }

    private func color(for category: String) -> Color {
        switch category {
        case "main_food":
            MHBTheme.ColorToken.primary.color
        case "wet_food":
            MHBTheme.ColorToken.teal.color
        case "treats":
            MHBTheme.ColorToken.warning.color
        case "nutrition":
            MHBTheme.ColorToken.success.color
        default:
            MHBTheme.ColorToken.labelQuaternary.color
        }
    }
}
