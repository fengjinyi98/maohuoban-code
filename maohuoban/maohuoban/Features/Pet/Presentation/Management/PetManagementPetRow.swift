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
                    titleRow

                    Text("\(pet.breedText) · \(pet.ageText)")
                        .font(MHBTheme.Typography.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    metaRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(MHBTheme.Typography.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(MHBTheme.ColorToken.labelQuaternary.color)
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.vertical, MHBTheme.Spacing.s4)
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

    private var titleRow: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Text(pet.name)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)
                .truncationMode(.tail)

            if let systemImage = pet.sex.systemImage {
                Image(systemName: systemImage)
                    .font(MHBTheme.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(sexIconColor)
            }
        }
    }

    private var metaRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                PetManagementTagStrip(tags: pet.statusTags)
                Spacer(minLength: MHBTheme.Spacing.s2)
                PetManagementCompanionshipText(days: pet.companionshipDays)
            }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                PetManagementTagStrip(tags: pet.statusTags)
                PetManagementCompanionshipText(days: pet.companionshipDays)
            }
        }
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
