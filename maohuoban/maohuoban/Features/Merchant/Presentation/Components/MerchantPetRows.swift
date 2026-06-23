import SwiftUI
import MaohuobanDesignSystem

// MerchantManagedPetRow 商家在管宠物行
// 核心职责：
// - 展示单只商家宠物的档案摘要
// - 呈现来源、状态和更新时间等追溯线索
struct MerchantManagedPetRow: View {
    let pet: MerchantManagedPet

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            MerchantPetSpeciesBadge(subject: pet.avatarSubject)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
                    Text(pet.name)
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text(pet.managedStatus.displayTitle)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                        .padding(.horizontal, MHBTheme.Spacing.s2)
                        .padding(.vertical, MHBTheme.Spacing.s1)
                        .background(MHBTheme.ColorToken.primaryBackground.color)
                        .clipShape(Capsule())
                }

                Text(petProfileText)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                Text("来源：\(String(localized: pet.sourceKind.displayTitle))")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

                Text("更新：\(pet.updatedAt)")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }

            Spacer(minLength: MHBTheme.Spacing.s2)
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 0.5)
        )
        .accessibilityIdentifier("merchant.pets.row.\(pet.id)")
    }

    private var petProfileText: String {
        let breedText: String
        if let breed = pet.breed, !breed.isEmpty {
            breedText = breed
        } else {
            breedText = String(localized: pet.species.displayTitle)
        }

        let birthdayText: String
        if let birthday = pet.birthday, !birthday.isEmpty {
            birthdayText = birthday
        } else {
            birthdayText = "生日待补"
        }

        return "\(breedText) · \(String(localized: pet.sex.displayTitle)) · \(birthdayText)"
    }
}

// MerchantPetSpeciesBadge 商家宠物物种标识
// 核心职责：
// - 使用统一图标表达宠物物种
// - 为列表行提供稳定视觉锚点
struct MerchantPetSpeciesBadge: View {
    let subject: MHBAvatarSubject

    var body: some View {
        MHBAvatar(
            subject: subject,
            size: .custom(MHBTheme.IconSize.avatar),
            shape: .squircle
        )
    }
}
