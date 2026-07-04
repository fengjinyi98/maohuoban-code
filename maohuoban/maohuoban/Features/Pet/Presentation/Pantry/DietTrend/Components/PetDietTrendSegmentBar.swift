import SwiftUI
import MaohuobanDesignSystem

// PetDietTrendSegmentBar 宠物饮食趋势分段条
// 核心职责：
// - 按后端返回占比渲染饮食品类结构
// - 在无数据时展示稳定空态轨道
struct PetDietTrendSegmentBar: View {
    let segments: [PetDietTrendSegmentPresentation]

    var body: some View {
        GeometryReader { proxy in
            let totalWidth = proxy.size.width

            HStack(spacing: 2) {
                if segments.isEmpty {
                    Capsule()
                        .fill(.white.opacity(0.12))
                        .frame(width: totalWidth)
                } else {
                    ForEach(segments) { segment in
                        Capsule()
                            .fill(segment.color)
                            .frame(width: segmentWidth(segment, totalWidth: totalWidth))
                    }
                }
            }
        }
        .frame(height: 8)
    }

    private func segmentWidth(
        _ segment: PetDietTrendSegmentPresentation,
        totalWidth: CGFloat
    ) -> CGFloat {
        let ratio = CGFloat(segment.percentage) / 100
        return max(totalWidth * ratio, 8)
    }
}
