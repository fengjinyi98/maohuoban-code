import SwiftUI
import MaohuobanDesignSystem

// ProfileFollowedTopicsSection 我关注的话题区块
// 核心职责：
// - 展示“我关注的话题”卡片头部（带右箭头入口）
// - 承载水平滚动的关注话题列表，呈现 Mock 宠物内容
struct ProfileFollowedTopicsSection: View {
    let topics: [ProfileFollowedTopic]
    let onHeaderClick: () -> Void
    let onTopicClick: (ProfileFollowedTopic) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            // Header Row
            Button(action: onHeaderClick) {
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

            // Horizontal ScrollView
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    ForEach(topics) { topic in
                        ProfileFollowedTopicItemView(topic: topic) {
                            onTopicClick(topic)
                        }
                    }
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
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
// - 渲染单个话题的方形缩略图、标题和动态数统计
private struct ProfileFollowedTopicItemView: View {
    let topic: ProfileFollowedTopic
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: MHBTheme.Spacing.s1) {
                Image(topic.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                            .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 1)
                    }

                Text(topic.title)
                    .font(MHBTheme.Typography.caption.bold())
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)
                    .frame(width: 72)
                    .multilineTextAlignment(.center)

                Text(topic.statsText)
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
