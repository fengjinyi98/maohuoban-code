import SwiftUI
import MaohuobanDesignSystem

// HomeTimelineSection 最近时间线模块
// 核心职责：
// - 展示当前宠物最近关键事件
// - 让用户感知宠物一生档案持续增长
struct HomeTimelineSection: View {
    let events: [HomeDashboardSnapshot.TimelineEvent]

    var body: some View {
        HomeCardContainer(accessibilityIdentifier: "home.timelineSection") {
            HomeSectionTitle("最近时间线", trailingTitle: "全部记录")

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                ForEach(events) { event in
                    HomeTimelineRow(event: event)
                }
            }
        }
    }
}

// HomeTimelineRow 时间线事件行
// 核心职责：
// - 展示单条事件摘要
// - 使用事件类型映射图标
private struct HomeTimelineRow: View {
    let event: HomeDashboardSnapshot.TimelineEvent

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: iconName)
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: MHBTheme.IconSize.large, height: MHBTheme.IconSize.large)
                .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(event.title)
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Text(event.subtitle)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer()

            Text(event.occurredText)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
    }

    private var iconName: String {
        switch event.eventKind {
        case .daily: "sparkles"
        case .weight: "scalemass.fill"
        case .vaccine: "syringe.fill"
        case .deworming: "bell.fill"
        case .health: "cross.case.fill"
        case .merchant: "checkmark.seal.fill"
        }
    }
}

