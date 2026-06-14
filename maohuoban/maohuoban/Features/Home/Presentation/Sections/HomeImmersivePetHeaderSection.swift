import SwiftUI
import MaohuobanDesignSystem

// HomeImmersivePetHeaderSection 首页沉浸式宠物头图
// 核心职责：
// - 展示当前宠物的首屏大图和核心状态
// - 让首页根视图保持装载职责
struct HomeImmersivePetHeaderSection: View {
    let pet: HomeDashboardSnapshot.PetHeroSummary

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(pet.heroImageAssetName ?? "HomePetHeroMock")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 340)
                .clipped()

            LinearGradient(
                stops: [
                    Gradient.Stop(color: .black.opacity(0.04), location: 0.0),
                    Gradient.Stop(color: .black.opacity(0.22), location: 0.46),
                    Gradient.Stop(color: .black.opacity(0.72), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            HomeImmersivePetHeaderContent(
                name: pet.name,
                breedText: "\(pet.ageText) · \(pet.breed)",
                statusText: pet.statusText,
                updatedText: pet.updatedText,
                sexText: sexText
            )
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.bottom, MHBTheme.Spacing.s6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 340)
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: MHBTheme.Radius.extraExtraLarge,
                bottomTrailingRadius: MHBTheme.Radius.extraExtraLarge,
                style: .continuous
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            MHBTheme.ColorToken.background.color.opacity(0),
                            MHBTheme.ColorToken.background.color
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: MHBTheme.Spacing.s6)
                .offset(y: MHBTheme.Spacing.s6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.immersivePetHeader")
    }

    private var sexText: LocalizedStringResource {
        switch pet.sex {
        case .female: "妹妹"
        case .male: "弟弟"
        case .unknown: "未知"
        }
    }
}

// HomeImmersivePetHeaderContent 宠物头图文字层
// 核心职责：
// - 展示宠物名称、基础信息和档案状态
// - 保持头图图片层与文字层职责分离
private struct HomeImmersivePetHeaderContent: View {
    let name: String
    let breedText: String
    let statusText: String
    let updatedText: String
    let sexText: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
                Text(name)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(sexText)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, MHBTheme.Spacing.s2)
                    .padding(.vertical, MHBTheme.Spacing.s1)
                    .glassEffect(.clear.interactive(false), in: .capsule)
            }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text(breedText)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)

                Text(statusText)
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(updatedText)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
