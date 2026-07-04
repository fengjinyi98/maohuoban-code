import SwiftUI
import MaohuobanDesignSystem

// PetPantryDietTrendSegmentBar 饮食趋势分段条
// 核心职责：
// - 按后端返回百分比渲染饮食品类占比
// - 保持空数据时的稳定占位高度
struct PetPantryDietTrendSegmentBar: View {
    let segments: [PetPantryDietTrendSegmentPresentation]

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                if activeSegments.isEmpty {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(MHBTheme.ColorToken.separatorSoft.color)
                        .frame(width: proxy.size.width)
                } else {
                    ForEach(activeSegments) { segment in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(color(for: segment.category))
                            .frame(width: segmentWidth(segment, totalWidth: proxy.size.width))
                    }
                }
            }
        }
        .frame(height: 14)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var activeSegments: [PetPantryDietTrendSegmentPresentation] {
        segments.filter { $0.percentage > 0 }
    }

    private func segmentWidth(
        _ segment: PetPantryDietTrendSegmentPresentation,
        totalWidth: CGFloat
    ) -> CGFloat {
        max(8, totalWidth * CGFloat(segment.percentage) / 100)
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
