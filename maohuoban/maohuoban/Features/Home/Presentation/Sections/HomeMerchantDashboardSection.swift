import SwiftUI
import MaohuobanDesignSystem

// HomeMerchantDashboardSection 商家工作台模块
// 核心职责：
// - 展示认证商家多宠状态和窝次入口
// - 展示待补记录等高优先级任务
struct HomeMerchantDashboardSection: View {
    let summary: HomeDashboardSnapshot.MerchantDashboardSummary

    var body: some View {
        HomeCardContainer(accessibilityIdentifier: "home.merchantDashboardSection") {
            HomeSectionTitle("机构宠物工作台")

            HStack(spacing: MHBTheme.Spacing.s2) {
                ForEach(summary.statusCounts) { count in
                    VStack(spacing: MHBTheme.Spacing.s1) {
                        Text("\(count.count)")
                            .font(MHBTheme.Typography.title)
                            .foregroundStyle(MHBTheme.ColorToken.primary.color)
                        Text(count.title)
                            .font(MHBTheme.Typography.caption)
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MHBTheme.Spacing.s3)
                    .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                }
            }

            ForEach(summary.litters) { litter in
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    Text(litter.name)
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    Text(litter.parentText)
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    Text("\(litter.bornText) · 可售 \(litter.availableCount)")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                }
                .padding(MHBTheme.Spacing.s3)
                .background(MHBTheme.ColorToken.primaryBackground.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
            }
        }
    }
}

