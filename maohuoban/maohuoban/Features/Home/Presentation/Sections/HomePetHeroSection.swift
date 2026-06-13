import SwiftUI
import MaohuobanDesignSystem

// HomePetHeroSection 宠物主卡模块
// 核心职责：
// - 展示当前宠物的首屏主体信息
// - 承接进入宠物档案的主入口视觉
struct HomePetHeroSection: View {
    let pet: HomeDashboardSnapshot.PetHeroSummary

    var body: some View {
        HomeCardContainer(accessibilityIdentifier: "home.petHeroCard") {
            HStack(alignment: .center, spacing: MHBTheme.Spacing.s4) {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                    HStack(spacing: MHBTheme.Spacing.s2) {
                        Text(pet.name)
                            .font(MHBTheme.Typography.title)
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                        Text(sexText)
                            .font(MHBTheme.Typography.caption)
                            .foregroundStyle(MHBTheme.ColorToken.primary.color)
                            .padding(.horizontal, MHBTheme.Spacing.s2)
                            .padding(.vertical, MHBTheme.Spacing.s1)
                            .background(MHBTheme.ColorToken.primaryBackground.color)
                            .clipShape(Capsule())
                    }

                    Text("\(pet.ageText) · \(pet.breed)")
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                    Text(pet.statusText)
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text(pet.updatedText)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(MHBTheme.ColorToken.primaryBackground.color)
                        .frame(width: MHBTheme.IconSize.avatar, height: MHBTheme.IconSize.avatar)

                    Image(systemName: petIcon)
                        .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                }
            }
        }
    }

    private var petIcon: String {
        switch pet.species {
        case .dog: "pawprint.fill"
        case .cat: "cat.fill"
        case .other: "heart.fill"
        }
    }

    private var sexText: LocalizedStringResource {
        switch pet.sex {
        case .female: "妹妹"
        case .male: "弟弟"
        case .unknown: "未知"
        }
    }
}

