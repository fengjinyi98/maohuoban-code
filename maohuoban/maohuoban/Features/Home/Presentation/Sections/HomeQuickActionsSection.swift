import SwiftUI
import MaohuobanDesignSystem

// HomeQuickActionsSection 快捷动作模块
// 核心职责：
// - 展示当前首页上下文可用动作
// - 为后续记录、医院和导入流程提供入口
struct HomeQuickActionsSection: View {
    let actions: [HomeDashboardSnapshot.Action]
    let routingContext: HomeActionRoutingContext

    var body: some View {
        HomeCardContainer(accessibilityIdentifier: "home.quickActionsSection") {
            HomeSectionTitle("快捷动作")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: MHBTheme.Spacing.s2), count: 3),
                spacing: MHBTheme.Spacing.s2
            ) {
                ForEach(actions) { action in
                    if let route = HomeActionRouteResolver.route(
                        for: action,
                        context: routingContext
                    ) {
                        NavigationLink(value: route) {
                            HomeQuickActionTile(action: action)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("home.quickAction.\(action.kind.rawValue)")
                    } else {
                        HomeQuickActionTile(action: action)
                            .opacity(0.45)
                            .accessibilityIdentifier("home.quickAction.\(action.kind.rawValue).disabled")
                    }
                }
            }
        }
    }
}

// HomeQuickActionTile 首页快捷动作图标块
// 核心职责：
// - 展示单个快捷动作的图标和标题
// - 让动作展示与导航有效性解耦
private struct HomeQuickActionTile: View {
    let action: HomeDashboardSnapshot.Action

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            Image(systemName: iconName(for: action.kind))
                .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: MHBTheme.IconSize.avatar, height: MHBTheme.IconSize.avatar)
                .background(MHBTheme.ColorToken.primaryBackground.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))

            Text(action.title)
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(minHeight: MHBTheme.Spacing.s8)
        }
        .frame(maxWidth: .infinity)
    }

    private func iconName(for kind: HomeDashboardSnapshot.Action.Kind) -> String {
        switch kind {
        case .createPet: "plus.circle.fill"
        case .dailyRecord: "square.and.pencil"
        case .healthRecord: "cross.case.fill"
        case .bookHospital: "stethoscope"
        case .importTradePet: "tray.and.arrow.down.fill"
        case .addMerchantPet: "pawprint.circle.fill"
        case .publishAvailableStatus: "tag.fill"
        }
    }
}
