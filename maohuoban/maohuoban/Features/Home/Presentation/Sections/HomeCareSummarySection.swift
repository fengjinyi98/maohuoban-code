import SwiftUI
import MaohuobanDesignSystem

// HomeCareSummarySection 今日照护模块
// 核心职责：
// - 展示今日照护指标
// - 展示最近提醒摘要
struct HomeCareSummarySection: View {
    let summary: HomeDashboardSnapshot.CareSummary
    let reminders: [HomeDashboardSnapshot.Reminder]
    let routingContext: HomeActionRoutingContext

    var body: some View {
        HomeCardContainer(accessibilityIdentifier: "home.careSummarySection") {
            HomeSectionTitle("今日照护")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: MHBTheme.Spacing.s2), count: 2),
                spacing: MHBTheme.Spacing.s2
            ) {
                ForEach(summary.metrics) { metric in
                    HomeCareMetricCell(metric: metric)
                }
            }

            ForEach(reminders) { reminder in
                HomeReminderNavigationRow(
                    reminder: reminder,
                    routingContext: routingContext
                )
            }
        }
    }
}

// HomeCareMetricCell 照护指标单元
// 核心职责：
// - 展示单项照护指标值和状态
// - 使用指标类型映射稳定图标
private struct HomeCareMetricCell: View {
    let metric: HomeDashboardSnapshot.CareMetric

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Image(systemName: iconName)
                .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: MHBTheme.IconSize.large, height: MHBTheme.IconSize.large)
                .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(metric.title)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                Text(metric.valueText)
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Text(metric.statusText)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }

    private var iconName: String {
        switch metric.kind {
        case .appetite: "fork.knife"
        case .mood: "face.smiling"
        case .excretion: "drop.fill"
        case .weight: "scalemass.fill"
        }
    }
}

// HomeReminderNavigationRow 首页提醒导航行
// 核心职责：
// - 根据提醒类型选择事件详情或商家待办入口
// - 在缺少必要上下文时保留静态提醒展示
private struct HomeReminderNavigationRow: View {
    let reminder: HomeDashboardSnapshot.Reminder
    let routingContext: HomeActionRoutingContext

    var body: some View {
        VStack(spacing: 0) {
            if let route = HomeReminderRouteResolver.route(
                for: reminder,
                context: routingContext
            ) {
                NavigationLink(value: route) {
                    HomeReminderRow(reminder: reminder, showsChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.reminder.\(reminder.id)")
            } else {
                HomeReminderRow(reminder: reminder, showsChevron: false)
                    .opacity(0.55)
                    .accessibilityIdentifier("home.reminder.\(reminder.id).disabled")
            }
        }
    }
}

// HomeReminderRow 首页提醒行
// 核心职责：
// - 展示最近一条待处理提醒
// - 连接后续提醒详情入口
private struct HomeReminderRow: View {
    let reminder: HomeDashboardSnapshot.Reminder
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "bell.fill")
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: MHBTheme.IconSize.large, height: MHBTheme.IconSize.large)
                .background(MHBTheme.ColorToken.cardSolid.color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(reminder.title)
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Text(reminder.subtitle)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer()

            Text(reminder.dueText)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.primary.color)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
        }
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.primaryBackground.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
