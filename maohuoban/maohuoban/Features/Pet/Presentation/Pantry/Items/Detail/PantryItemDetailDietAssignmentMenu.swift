import SwiftUI

// PantryItemDetailDietAssignmentMenu 物品饮食配置菜单
// 核心职责：
// - 根据物品分类提供可用饮食配置动作
// - 将具体动作转发给详情页 Store
struct PantryItemDetailDietAssignmentMenu: View {
    let item: PantryItem
    let onSetCurrentStaple: () -> Void
    let onSetTrying: () -> Void
    let onSetUsualTreat: () -> Void
    let onSetUsualNutrition: () -> Void
    let onSetNotSuitable: () -> Void

    var body: some View {
        Section("饮食配置") {
            switch item.category {
            case .mainFood, .wetFood:
                Button("设为当前主粮", systemImage: "takeoutbag.and.cup.and.straw.fill", action: onSetCurrentStaple)
                Button("标记为尝试中", systemImage: "sparkles", action: onSetTrying)
            case .treats:
                Button("设为常用零食", systemImage: "birthday.cake.fill", action: onSetUsualTreat)
            case .supplements:
                Button("设为常用营养品", systemImage: "pills.fill", action: onSetUsualNutrition)
            case .other:
                Button("标记为尝试中", systemImage: "sparkles", action: onSetTrying)
            case .all, .catLitter, .medicine:
                EmptyView()
            }
            Button("设为不适合", systemImage: "xmark.octagon.fill", action: onSetNotSuitable)
        }
    }
}
