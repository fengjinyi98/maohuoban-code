import SwiftUI
import MaohuobanDesignSystem

// PantryItemLinkedPetRow 关联宠物行
// 核心职责：
// - 展示单只关联宠物名称和来源
struct PantryItemLinkedPetRow: View {
    let pet: FoodInventoryLinkedPet

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            PantryItemLinkedPetAvatar(
                petID: pet.petID,
                petName: pet.petName,
                avatarURLString: pet.avatarURL,
                species: pet.species,
                sex: pet.sex
            )

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(pet.petName)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Text(pet.source.pantryLinkedPetSourceText)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer(minLength: MHBTheme.Spacing.s2)
        }
    }
}
