import SwiftUI
import MaohuobanDesignSystem

// HomeDietTrendDetailMetricGrid 饮食趋势详情指标区
// 核心职责：
// - 展示样本进度、基线进度和库存校准状态
// - 保持指标文案来自展示模型
struct HomeDietTrendDetailMetricGrid: View {
    let presentation: HomeDietTrendPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("分析进度")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            VStack(spacing: MHBTheme.Spacing.s3) {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    HomeDietTrendDetailMetricItem(
                        title: "健康样本",
                        value: presentation.sampleSummaryText
                    )
                    HomeDietTrendDetailMetricItem(
                        title: "个体基线",
                        value: presentation.baselineProgressText
                    )
                }

                HomeDietTrendDetailMetricItem(
                    title: presentation.calibrationStatusText,
                    value: presentation.calibrationDetailText
                )
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}

