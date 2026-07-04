import SwiftUI
import MaohuobanDesignSystem

// PetDietTrendLegendItem 首页饮食趋势图例项
// 核心职责：
// - 展示单个饮食品类的颜色、名称和占比
// - 保持首页趋势摘要可快速扫读
struct PetDietTrendLegendItem: View {
    let segment: PetDietTrendSegmentPresentation

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(segment.color)
                .frame(width: 6, height: 6)

            Text(segment.title)
                .lineLimit(1)

            Text(segment.percentageText)
                .foregroundStyle(.white.opacity(0.5))
        }
        .font(MHBTheme.Typography.caption.weight(.medium))
        .foregroundStyle(.white.opacity(0.72))
    }
}
