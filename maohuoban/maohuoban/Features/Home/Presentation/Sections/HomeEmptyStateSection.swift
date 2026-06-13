import SwiftUI
import MaohuobanDesignSystem

// HomeEmptyStateSection 首页空态模块
// 核心职责：
// - 展示无宠物或未认证等首页引导状态
// - 保持创建宠物或认证为主操作
struct HomeEmptyStateSection: View {
    let emptyState: HomeDashboardSnapshot.EmptyState
    let recommendedContent: [HomeDashboardSnapshot.RecommendedContent]
    let routingContext: HomeActionRoutingContext

    var body: some View {
        HomeCardContainer(accessibilityIdentifier: "home.emptyStateSection") {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                Text(emptyState.title)
                    .font(MHBTheme.Typography.title)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(emptyState.subtitle)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)

                if let route = HomeActionRouteResolver.route(
                    for: emptyState.primaryAction,
                    context: routingContext
                ) {
                    NavigationLink(value: route) {
                        HomeEmptyPrimaryActionLabel(title: emptyState.primaryAction.title)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.emptyState.primaryAction")
                } else {
                    HomeEmptyPrimaryActionLabel(title: emptyState.primaryAction.title)
                        .opacity(0.45)
                        .accessibilityIdentifier("home.emptyState.primaryAction.disabled")
                }
            }

            if !recommendedContent.isEmpty {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    HomeSectionTitle("给新手的参考")

                    ForEach(recommendedContent) { content in
                        HStack {
                            Text(content.title)
                                .font(MHBTheme.Typography.callout)
                                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                            Spacer()
                            Text(content.sourceText)
                                .font(MHBTheme.Typography.caption)
                                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        }
                    }
                }
            }
        }
    }
}

// HomeEmptyPrimaryActionLabel 首页空态主操作标签
// 核心职责：
// - 统一空态主操作视觉
// - 让导航有效性和按钮外观解耦
private struct HomeEmptyPrimaryActionLabel: View {
    let title: String

    var body: some View {
        Label(title, systemImage: "plus.circle.fill")
            .font(MHBTheme.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, MHBTheme.Spacing.s3)
            .background(MHBTheme.ColorToken.primary.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
