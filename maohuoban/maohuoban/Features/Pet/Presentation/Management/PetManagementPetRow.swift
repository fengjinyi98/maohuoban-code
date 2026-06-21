import SwiftUI
import MaohuobanDesignSystem

// PetManagementPetRow 我的宠物列表行
// 核心职责：
// - 按设计稿展示头像、名称、品种年龄、状态和陪伴天数
// - 将整行点击转发为打开宠物档案事件
struct PetManagementPetRow: View {
    let pet: PetManagementPet
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                PetManagementPetAvatar(
                    assetName: pet.avatarAssetName,
                    avatarURL: pet.avatarURL,
                    species: pet.species
                )

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    HStack(alignment: .center) {
                        HStack(spacing: MHBTheme.Spacing.s1) {
                            Text(pet.name)
                                .font(MHBTheme.Typography.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            if let systemImage = pet.sex.systemImage {
                                Image(systemName: systemImage)
                                    .font(MHBTheme.Typography.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(sexIconColor)
                            }
                        }

                        Spacer()

                        PetManagementCompanionshipText(days: pet.companionshipDays)
                    }

                    HStack(alignment: .center) {
                        Text("\(pet.breedText) · \(pet.ageText)")
                            .font(MHBTheme.Typography.footnote)
                            .fontWeight(.medium)
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()

                        PetManagementTagStrip(tags: pet.statusTags)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(MHBTheme.Typography.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(MHBTheme.ColorToken.labelQuaternary.color)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(MHBTheme.ColorToken.cardSolid.color)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(MHBTheme.ColorToken.separator.color)
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pet.name)，\(pet.breedText)，\(pet.ageText)")
        .accessibilityIdentifier("pet.management.row.\(pet.id)")
    }

    private var sexIconColor: Color {
        switch pet.sex {
        case .male:
            MHBTheme.ColorToken.primary.color
        case .female:
            MHBTheme.ColorToken.danger.color.opacity(0.78)
        case .unknown:
            MHBTheme.ColorToken.labelTertiary.color
        }
    }
}
