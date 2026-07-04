import SwiftUI
import MaohuobanDesignSystem

// PantryItemConsumptionSummarySection 物品消耗统计区
// 核心职责：
// - 展示物品维度的消耗分析结论和证据
// - 保持统计结论来自后端读模型
struct PantryItemConsumptionSummarySection: View {
    let summary: FoodInventoryConsumptionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            Text("消耗分析")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text(summary.headline)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .fixedSize(horizontal: false, vertical: true)

                Text(summary.usageRhythm)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)

                Text(summary.portionStability)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)

                Text(summary.calibrationState)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: MHBTheme.Spacing.s3) {
                PantryItemConsumptionMetric(title: "喂食次数", value: "\(summary.feedingCount)")
                PantryItemConsumptionMetric(title: "使用跨度", value: "\(summary.activeDays) 天")
            }

            if !summary.observations.isEmpty {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    ForEach(summary.observations, id: \.self) { observation in
                        PantryItemConsumptionObservationRow(text: observation)
                    }
                }
            }

            if !summary.amountDistribution.isEmpty {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                    ForEach(summary.amountDistribution) { item in
                        PantryItemAmountDistributionRow(item: item)
                    }
                }
            } else {
                Text("暂无喂食记录")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, MHBTheme.Spacing.s3)
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
