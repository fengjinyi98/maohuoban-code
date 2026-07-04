import SwiftUI
import MaohuobanDesignSystem

// PantryItemConsumptionObservationRow 物品消耗观察行
// 核心职责：
// - 展示单条物品维度消耗分析结论
// - 统一消耗分析区的观察列表样式
struct PantryItemConsumptionObservationRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s2) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.success.color)
                .padding(.top, 2)

            Text(text)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
