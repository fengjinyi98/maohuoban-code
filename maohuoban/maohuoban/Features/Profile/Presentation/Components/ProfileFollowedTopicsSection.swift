import SwiftUI
import MaohuobanDesignSystem

// ProfileFollowedTopicsSection 我关注的话题区块
// 核心职责：
// - 展示“我关注的话题”卡片头部（带右箭头入口）
// - 承载水平滚动的关注话题列表并进入话题功能页
struct ProfileFollowedTopicsSection<Route: Hashable>: View {
    let topics: [TopicSummary]
    let headerRoute: Route
    let topicRoute: (TopicSummary) -> Route

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            NavigationLink(value: headerRoute) {
                HStack {
                    Text("我关注的话题")
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
            }
            .buttonStyle(.plain)

            if topics.isEmpty {
                ProfileFollowedTopicEmptyHint()
                    .padding(.horizontal, MHBTheme.Spacing.s4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MHBTheme.Spacing.s3) {
                        ForEach(topics) { topic in
                            ProfileFollowedTopicItemView(
                                topic: topic,
                                route: topicRoute(topic)
                            )
                        }
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                }
            }
        }
        .padding(.vertical, MHBTheme.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraExtraLarge, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.followedTopics")
    }
}

// ProfileFollowedTopicItemView 话题卡片中的单个话题视图
// 核心职责：
// - 渲染单个话题的方形缩略图、标题和更新状态
private struct ProfileFollowedTopicItemView<Route: Hashable>: View {
    let topic: TopicSummary
    let route: Route

    var body: some View {
        NavigationLink(value: route) {
            VStack(alignment: .center, spacing: MHBTheme.Spacing.s1) {
                Image(topic.thumbnailAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                        .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 1)
                    }

                Text(topic.name)
                    .font(MHBTheme.Typography.caption.bold())
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)
                    .frame(width: 72)
                    .multilineTextAlignment(.center)

                Text(topic.updateText)
                    .font(MHBTheme.Typography.section)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
                    .frame(width: 72)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
    }
}

// ProfileFollowedTopicEmptyHint 我关注的话题空提示
// 核心职责：
// - 在我的页关注话题为空时提供轻量入口提示
private struct ProfileFollowedTopicEmptyHint: View {
    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Image(systemName: "number")
                .foregroundStyle(MHBTheme.ColorToken.primary.color)

            Text("创建或关注话题后会显示在这里")
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.separatorSoft.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}
