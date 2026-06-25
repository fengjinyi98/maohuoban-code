import SwiftUI
import MaohuobanDesignSystem

// HomeOpenAbnormalEpisodeHintSection 首页未闭环异常轻提示
// 核心职责：
// - 在时间线上方展示未标记恢复的异常事件入口
// - 不使用背景、描边或卡片容器，只通过图标颜色表达提醒
// - 点击后进入异常事件详情页继续追加观察、关联就诊或标记恢复
struct HomeOpenAbnormalEpisodeHintSection: View {
    let petName: String?
    let event: HomeDashboardSnapshot.TimelineEvent
    let openCount: Int

    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.warning.color)
                    .frame(width: 28, height: 28)

                Text(messageText)
                    .font(MHBTheme.Typography.callout.weight(.medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: MHBTheme.Spacing.s3)

                HStack(spacing: MHBTheme.Spacing.s1) {
                    Text("查看")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.openAbnormalEpisodeHint")
    }

    private var route: HomeRoute {
        .petRecordDetail(.abnormal(recordID: event.id))
    }

    private var messageText: String {
        let name = petName?.isEmpty == false ? petName ?? "宠物" : "宠物"
        if openCount > 1 {
            return "\(name)有 \(openCount) 条异常记录待跟进"
        }
        return "\(name)有 1 条异常记录待跟进"
    }
}

extension HomeDashboardSnapshot {
    // homeOpenAbnormalHintEvents 首页未闭环异常展示兜底
    // 核心职责：
    // - 在快速 UI 阶段从时间线中识别可展示的异常事件
    // - 后端接入后由 open_abnormal_episode_count 控制显隐和数量文案
    // - 后端接入后由 latest_open_abnormal_episode_id 控制跳转到最新未恢复异常事件
    var homeOpenAbnormalHintEvents: [TimelineEvent] {
        guard recentTimeline.contains(where: \.homeLooksLikeRecoveryRecord) == false else {
            return []
        }

        return recentTimeline.filter(\.homeLooksLikeOpenAbnormalRecord)
    }

    var homeLatestOpenAbnormalHintEvent: TimelineEvent? {
        homeOpenAbnormalHintEvents.first
    }
}

private extension HomeDashboardSnapshot.TimelineEvent {
    var homeLooksLikeOpenAbnormalRecord: Bool {
        eventKind == .health && homeCombinedText.contains("异常")
    }

    var homeLooksLikeRecoveryRecord: Bool {
        homeCombinedText.contains("恢复")
            || homeCombinedText.contains("已恢复")
            || homeCombinedText.contains("标记恢复")
    }

    var homeCombinedText: String {
        "\(title) \(subtitle)"
    }
}
