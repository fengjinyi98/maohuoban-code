import SwiftUI
import MaohuobanDesignSystem

// PantryItemLinkedPetsSection 关联宠物区
// 核心职责：
// - 展示后端聚合出的物品关联宠物
// - 标注关联来源用于用户理解
struct PantryItemLinkedPetsSection: View {
    let linkedPets: [FoodInventoryLinkedPet]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            Text("关联宠物")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            if linkedPets.isEmpty {
                Text("暂无关联宠物")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: MHBTheme.Spacing.s3) {
                    ForEach(linkedPets) { pet in
                        PantryItemLinkedPetRow(pet: pet)
                    }
                }
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
