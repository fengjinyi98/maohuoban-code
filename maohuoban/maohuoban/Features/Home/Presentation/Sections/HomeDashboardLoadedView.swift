import SwiftUI
import MaohuobanDesignSystem

// HomeDashboardLoadedView 首页已加载内容
// 核心职责：
// - 按首页快照组合各业务 section
// - 保持 HomeRootScreen 只负责状态切换
struct HomeDashboardLoadedView: View {
    let snapshot: HomeDashboardSnapshot
    let onSelectPet: (String) -> Void

    var body: some View {
        let routingContext = HomeActionRoutingContext(snapshot: snapshot)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                HomeIdentityHeader(identity: snapshot.identity)

                if !snapshot.petSwitcher.isEmpty {
                    HomePetSwitcherSection(
                        items: snapshot.petSwitcher,
                        onSelectPet: onSelectPet
                    )
                }

                if let emptyState = snapshot.emptyState {
                    HomeEmptyStateSection(
                        emptyState: emptyState,
                        recommendedContent: snapshot.recommendedContent,
                        routingContext: routingContext
                    )
                }

                if let selectedPet = snapshot.selectedPet {
                    HomePetHeroSection(pet: selectedPet)
                }

                if let careSummary = snapshot.careSummary {
                    HomeCareSummarySection(
                        summary: careSummary,
                        reminders: snapshot.reminders,
                        routingContext: routingContext
                    )
                }

                if !snapshot.quickActions.isEmpty {
                    HomeQuickActionsSection(
                        actions: snapshot.quickActions,
                        routingContext: routingContext
                    )
                }

                if let partner = snapshot.partnerRecommendation {
                    HomePartnerSection(partner: partner)
                }

                if !snapshot.recentTimeline.isEmpty {
                    HomeTimelineSection(events: snapshot.recentTimeline)
                }

                if let merchantDashboard = snapshot.merchantDashboard {
                    HomeMerchantDashboardSection(summary: merchantDashboard)
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
            .accessibilityIdentifier("home.dashboard")
        }
        .background(MHBTheme.ColorToken.background.color)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

// HomeIdentityHeader 首页身份头部
// 核心职责：
// - 展示当前身份名称和认证状态
// - 为普通用户和商家首页建立上下文
private struct HomeIdentityHeader: View {
    let identity: HomeDashboardSnapshot.Identity

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Text(identity.displayName)
                .font(MHBTheme.Typography.largeTitle)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Spacer()

            if let badge = identity.verificationBadge {
                Text(badge)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .padding(.horizontal, MHBTheme.Spacing.s3)
                    .padding(.vertical, MHBTheme.Spacing.s2)
                    .background(MHBTheme.ColorToken.primaryBackground.color)
                    .clipShape(Capsule())
            }
        }
        .accessibilityIdentifier("home.identityHeader")
    }
}
