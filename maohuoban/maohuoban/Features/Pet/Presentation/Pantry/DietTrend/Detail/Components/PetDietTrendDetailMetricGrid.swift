import SwiftUI
import MaohuobanDesignSystem

// PetDietTrendDetailMetricGrid 饮食趋势详情指标区
// 核心职责：
// - 展示样本进度、基线进度和库存校准状态
// - 保持指标文案来自展示模型
struct PetDietTrendDetailMetricGrid: View {
    let presentation: PetDietTrendPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("分析进度")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            VStack(spacing: MHBTheme.Spacing.s3) {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    PetDietTrendDetailMetricItem(
                        title: "健康样本",
                        value: presentation.sampleSummaryText,
                        icon: "doc.text.fill",
                        iconColor: MHBTheme.ColorToken.primary.color
                    )
                    PetDietTrendDetailMetricItem(
                        title: "个体基线",
                        value: presentation.baselineProgressText,
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: MHBTheme.ColorToken.success.color
                    )
                }
                .fixedSize(horizontal: false, vertical: true)

                PetDietTrendDetailMetricItem(
                    title: presentation.calibrationStatusText,
                    value: presentation.calibrationDetailText,
                    icon: "scale.3d",
                    iconColor: MHBTheme.ColorToken.warning.color
                )
            }
        }
    }
}

