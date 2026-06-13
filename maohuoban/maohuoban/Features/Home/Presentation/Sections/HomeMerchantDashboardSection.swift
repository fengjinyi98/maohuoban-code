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
                    NavigationLink(
                        value: HomeRoute.merchantPets(
                            merchantID: summary.merchantID,
                            status: count.status.rawValue
                        )
                    ) {
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
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.merchant.status.\(count.status.rawValue)")
                }
            }

            ForEach(summary.litters) { litter in
                NavigationLink(value: HomeRoute.merchantLitter(litterID: litter.id)) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(MHBTheme.Spacing.s3)
                    .background(MHBTheme.ColorToken.primaryBackground.color)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.merchant.litter.\(litter.id)")
            }

            if !summary.pendingTasks.isEmpty {
                HomeSectionTitle("待处理")

                ForEach(summary.pendingTasks) { reminder in
                    NavigationLink(value: HomeRoute.merchantTask(reminderID: reminder.id)) {
                        HomeMerchantTaskRow(reminder: reminder)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.merchant.pendingTask.\(reminder.id)")
                }
            }

            if !summary.recentEvents.isEmpty {
                HomeSectionTitle("店内宠物动态")

                ForEach(summary.recentEvents) { event in
                    NavigationLink(value: HomeRoute.timelineEvent(eventID: event.id)) {
                        HomeMerchantEventRow(event: event)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.merchant.recentEvent.\(event.id)")
                }
            }
        }
    }
}

// HomeMerchantTaskRow 商家待办行
// 核心职责：
// - 展示商家首页待处理任务摘要
// - 保持任务行样式和点击目标解耦
private struct HomeMerchantTaskRow: View {
    let reminder: HomeDashboardSnapshot.Reminder

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "checklist")
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
        }
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.primaryBackground.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}

// HomeMerchantEventRow 商家近期事件行
// 核心职责：
// - 展示店内宠物或窝次最近事件
// - 连接完整宠物事件账本入口
private struct HomeMerchantEventRow: View {
    let event: HomeDashboardSnapshot.TimelineEvent

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: MHBTheme.IconSize.large, height: MHBTheme.IconSize.large)
                .background(MHBTheme.ColorToken.cardSolid.color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(event.title)
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Text(event.subtitle)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer()

            Text(event.occurredText)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
