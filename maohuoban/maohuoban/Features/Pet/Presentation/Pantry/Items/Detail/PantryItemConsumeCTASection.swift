import SwiftUI
import MaohuobanDesignSystem

// PantryItemConsumeCTASection 物品消耗确认 CTA
// 核心职责：
// - 承载用户低心智确认“已吃完”的入口
// - 根据库存状态控制按钮可用性
struct PantryItemConsumeCTASection: View {
    let item: FoodInventoryItem
    let isSubmitting: Bool
    let onConsumeOne: () -> Void

    private var isEnabled: Bool {
        item.quantity > 0
            && item.inventoryStatus != .depleted
            && item.inventoryStatus != .archived
            && !isSubmitting
    }

    var body: some View {
        Button(action: onConsumeOne) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                }
                Text("已吃完")
                    .font(MHBTheme.Typography.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? MHBTheme.ColorToken.background.color : MHBTheme.ColorToken.labelSecondary.color)
        .background(
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .fill(isEnabled ? MHBTheme.ColorToken.labelPrimary.color : MHBTheme.ColorToken.cardSolid.color)
        )
        .disabled(!isEnabled)
        .accessibilityLabel("已吃完")
    }
}
