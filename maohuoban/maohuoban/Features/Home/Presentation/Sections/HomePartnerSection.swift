import SwiftUI
import MaohuobanDesignSystem

// HomePartnerSection 今日伙伴模块
// 核心职责：
// - 展示一条高质量宠物关系提示
// - 承接进入宠物世界或宠物主页的关系入口
struct HomePartnerSection: View {
    let partner: HomeDashboardSnapshot.PartnerRecommendation

    var body: some View {
        HomeCardContainer(accessibilityIdentifier: "home.partnerSection") {
            HomeSectionTitle("今日伙伴", trailingTitle: "查看主页")

            HStack(spacing: MHBTheme.Spacing.s3) {
                ZStack {
                    Circle()
                        .fill(MHBTheme.ColorToken.primaryBackground.color)
                        .frame(width: MHBTheme.IconSize.avatar, height: MHBTheme.IconSize.avatar)

                    Image(systemName: "pawprint.fill")
                        .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                }

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    Text(partner.petName)
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text(partner.subtitle)
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .fixedSize(horizontal: false, vertical: true)

                    if let distanceText = partner.distanceText {
                        Text(distanceText)
                            .font(MHBTheme.Typography.caption)
                            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    }
                }

                Spacer()
            }
        }
    }
}

