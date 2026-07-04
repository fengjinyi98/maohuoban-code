import SwiftUI
import MaohuobanDesignSystem

// HomeDietTrendDetailSegmentMetrics 饮食品类基线明细区
// 核心职责：
// - 展示每个品类的分数、基线、相对比例和 EMA
// - 保持计算结果完全来自后端读模型
struct HomeDietTrendDetailSegmentMetrics: View {
    let segments: [HomeDietTrendSegmentPresentation]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("品类基线")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            VStack(spacing: MHBTheme.Spacing.s3) {
                ForEach(segments) { segment in
                    HomeDietTrendDetailSegmentMetricRow(segment: segment)
                }
            }
        }
    }
}

