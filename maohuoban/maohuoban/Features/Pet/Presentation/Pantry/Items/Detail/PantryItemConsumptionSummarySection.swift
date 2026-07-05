import SwiftUI
import MaohuobanDesignSystem

// PantryItemConsumptionSummarySection 物品消耗统计区
// 核心职责：
// - 展示喂食次数、使用跨度和模糊份量分布
// - 保持统计结论来自后端读模型
struct PantryItemConsumptionSummarySection: View {
    let summary: FoodInventoryConsumptionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            Text("消耗分析")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            HStack(spacing: MHBTheme.Spacing.s3) {
                PantryItemConsumptionMetric(title: "喂食次数", value: "\(summary.feedingCount)")
                PantryItemConsumptionMetric(title: "使用跨度", value: "\(summary.activeDays) 天")
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
