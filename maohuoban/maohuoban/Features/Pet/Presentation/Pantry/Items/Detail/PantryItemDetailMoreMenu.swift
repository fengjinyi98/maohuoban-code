import SwiftUI
import MaohuobanDesignSystem

// PantryItemDetailMoreMenu 物品详情更多菜单
// 核心职责：
// - 承载物品状态、饮食配置、编辑、补库存和删除操作
// - 替代原物品点击 sheet 的操作入口
struct PantryItemDetailMoreMenu: View {
    let item: PantryItem
    let allowsDietAssignment: Bool
    let isDisabled: Bool
    let onMarkSealed: () -> Void
    let onRestock: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSetCurrentStaple: () -> Void
    let onSetTrying: () -> Void
    let onSetUsualTreat: () -> Void
    let onSetUsualNutrition: () -> Void
    let onSetNotSuitable: () -> Void

    var body: some View {
        Menu {
            Button("标记为全新未拆封", systemImage: "shippingbox", action: onMarkSealed)
            Button("补充库存", systemImage: "plus.circle", action: onRestock)

            if allowsDietAssignment {
                PantryItemDetailDietAssignmentMenu(
                    item: item,
                    onSetCurrentStaple: onSetCurrentStaple,
                    onSetTrying: onSetTrying,
                    onSetUsualTreat: onSetUsualTreat,
                    onSetUsualNutrition: onSetUsualNutrition,
                    onSetNotSuitable: onSetNotSuitable
                )
            }

            Button("编辑物品信息", systemImage: "pencil", action: onEdit)

            Button("移出储物柜", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
        .disabled(isDisabled)
        .accessibilityLabel("更多操作")
    }
}
