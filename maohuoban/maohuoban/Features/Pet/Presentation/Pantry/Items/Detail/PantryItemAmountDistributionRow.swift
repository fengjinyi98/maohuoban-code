import SwiftUI
import MaohuobanDesignSystem

// PantryItemAmountDistributionRow 份量分布行
// 核心职责：
// - 展示单个模糊份量的次数和比例
struct PantryItemAmountDistributionRow: View {
    let item: FoodInventoryAmountDistributionItem

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            HStack {
                Text(item.amountText)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Spacer()
                Text("\(item.count) 次")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MHBTheme.ColorToken.separatorSoft.color)
                    Capsule()
                        .fill(MHBTheme.ColorToken.primary.color)
                        .frame(width: max(6, proxy.size.width * item.ratio))
                }
            }
            .frame(height: 8)
        }
    }
}
