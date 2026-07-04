import SwiftUI
import MaohuobanDesignSystem

// PantryItemConsumptionMetric 消耗指标
// 核心职责：
// - 展示单个消耗分析数字
struct PantryItemConsumptionMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            Text(title)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.separatorSoft.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))
    }
}
