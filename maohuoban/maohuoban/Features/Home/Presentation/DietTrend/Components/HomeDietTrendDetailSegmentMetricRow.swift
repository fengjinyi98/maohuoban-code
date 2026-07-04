import SwiftUI
import MaohuobanDesignSystem

// HomeDietTrendDetailSegmentMetricRow 饮食品类基线明细行
// 核心职责：
// - 展示单个品类的趋势分析字段
// - 支撑用户理解当前占比与自身基线的关系
struct HomeDietTrendDetailSegmentMetricRow: View {
    let segment: HomeDietTrendSegmentPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Circle()
                    .fill(segment.color)
                    .frame(width: 8, height: 8)

                Text(segment.title)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Spacer()

                Text(segment.percentageText)
                    .font(MHBTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            HStack(spacing: MHBTheme.Spacing.s2) {
                metric(title: "分数", value: segment.scoreText)
                metric(title: "基线", value: segment.baselineText)
                metric(title: "相对", value: segment.ratioText)
                metric(title: "趋势", value: segment.emaText)
            }
        }
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Text(value)
                .font(MHBTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
