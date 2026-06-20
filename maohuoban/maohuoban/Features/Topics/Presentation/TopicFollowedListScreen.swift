import SwiftUI
import MaohuobanDesignSystem

// TopicFollowedListScreen 我关注的话题列表页
// 核心职责：
// - 展示当前用户已关注话题和更新状态
// - 通过所属 Tab 注入的话题详情路由承载系统跳转
struct TopicFollowedListScreen<DetailRoute: Hashable>: View {
    let store: TopicStore
    let detailRoute: (TopicSummary) -> DetailRoute

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                TopicFollowedSummaryHeader(count: store.followedTopics.count)

                if store.followedTopics.isEmpty {
                    TopicFollowedEmptyState()
                } else {
                    VStack(spacing: MHBTheme.Spacing.s3) {
                        ForEach(store.followedTopics) { topic in
                            TopicFollowedListRow(
                                topic: topic,
                                isFollowed: store.isFollowed(topicID: topic.id),
                                route: detailRoute(topic),
                                onToggleFollow: {
                                    store.toggleFollow(topicID: topic.id)
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("topics.followedList")
    }
}

// TopicCreatePanel 话题创建输入面板
// 核心职责：
// - 承载用户手动输入话题名的控件
// - 将创建动作限制在显式按钮点击边界
struct TopicCreatePanel: View {
    @Binding var draftName: String
    let title: String
    let prompt: String
    let buttonTitle: String
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(title)
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(prompt)
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: MHBTheme.Spacing.s2) {
                TextField("输入话题名", text: $draftName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(MHBTheme.Typography.callout)
                    .padding(.horizontal, MHBTheme.Spacing.s3)
                    .frame(height: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s3)
                    .background(MHBTheme.ColorToken.separatorSoft.color)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))

                Button {
                    onSubmit()
                } label: {
                    Text(buttonTitle)
                        .font(MHBTheme.Typography.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, MHBTheme.Spacing.s3)
                        .frame(height: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s3)
                        .background(submitBackgroundColor, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
    }

    private var canSubmit: Bool {
        !TopicIdentifier.normalizedName(draftName).isEmpty
    }

    private var submitBackgroundColor: Color {
        canSubmit ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelQuaternary.color
    }
}

// TopicFollowedSummaryHeader 关注话题列表头部
// 核心职责：
// - 展示当前关注话题总数
// - 保持列表页和我的页入口的信息口径一致
private struct TopicFollowedSummaryHeader: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            Text("我关注的话题")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("共 \(count) 个订阅")
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .padding(.top, MHBTheme.Spacing.s2)
    }
}

// TopicFollowedListRow 已关注话题行
// 核心职责：
// - 展示话题封面、名称、更新状态和关注按钮
// - 将详情跳转与关注切换拆成独立点击目标
private struct TopicFollowedListRow<DetailRoute: Hashable>: View {
    let topic: TopicSummary
    let isFollowed: Bool
    let route: DetailRoute
    let onToggleFollow: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            TopicFollowedListLink(
                topic: topic,
                route: route,
                statsText: "\(topic.postCount) 篇动态 · \(topic.followerCount) 人关注"
            )

            TopicFollowButton(
                isFollowed: isFollowed,
                onToggleFollow: onToggleFollow
            )
        }
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
    }
}

// TopicFollowedListLink 已关注话题详情跳转区
// 核心职责：
// - 承载话题行内进入详情页的点击区域
private struct TopicFollowedListLink<DetailRoute: Hashable>: View {
    let topic: TopicSummary
    let route: DetailRoute
    let statsText: String

    var body: some View {
        NavigationLink(value: route) {
            TopicFollowedListNavigationContent(
                assetName: topic.thumbnailAssetName,
                showUnreadDot: topic.todayPostCount > 0,
                title: topic.displayName,
                updateText: topic.updateText,
                statsText: statsText
            )
        }
        .buttonStyle(.plain)
    }
}

// TopicFollowButton 话题关注按钮
// 核心职责：
// - 展示关注状态
// - 响应用户关注或取消关注动作
private struct TopicFollowButton: View {
    let isFollowed: Bool
    let onToggleFollow: () -> Void

    var body: some View {
        Button {
            onToggleFollow()
        } label: {
            TopicFollowButtonLabel(
                title: isFollowed ? "已关注" : "关注",
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor
            )
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        isFollowed ? MHBTheme.ColorToken.labelSecondary.color : .white
    }

    private var backgroundColor: Color {
        isFollowed ? MHBTheme.ColorToken.separatorSoft.color : MHBTheme.ColorToken.primary.color
    }
}

// TopicFollowButtonLabel 话题关注按钮标签
// 核心职责：
// - 渲染关注按钮文字、颜色和胶囊背景
private struct TopicFollowButtonLabel: View {
    let title: String
    let foregroundColor: Color
    let backgroundColor: Color

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundColor(foregroundColor)
            .frame(minWidth: 58, minHeight: MHBTheme.Spacing.s6 + MHBTheme.Spacing.s1)
            .background {
                Capsule().fill(backgroundColor)
            }
    }
}

// TopicFollowedListNavigationContent 已关注话题跳转内容
// 核心职责：
// - 承载话题行内可进入详情页的图文区域
private struct TopicFollowedListNavigationContent: View {
    let assetName: String
    let showUnreadDot: Bool
    let title: String
    let updateText: String
    let statsText: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            TopicAvatarView(assetName: assetName, showUnreadDot: showUnreadDot)

            TopicFollowedListRowText(
                title: title,
                updateText: updateText,
                statsText: statsText
            )
        }
        .contentShape(Rectangle())
    }
}

// TopicFollowedListRowText 已关注话题行文本
// 核心职责：
// - 展示话题名称、更新文案和统计信息
private struct TopicFollowedListRowText: View {
    let title: String
    let updateText: String
    let statsText: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            Text(title)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)

            Text(updateText)
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .lineLimit(1)

            Text(statsText)
                .font(MHBTheme.Typography.section)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// TopicFollowedEmptyState 关注话题空态
// 核心职责：
// - 在没有关注话题时提示用户创建或关注话题
private struct TopicFollowedEmptyState: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "number.circle")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)

            Text("还没有关注话题")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("创建一个话题后，会出现在这里。")
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(MHBTheme.Spacing.s6)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
    }
}

// TopicAvatarView 话题头像视图
// 核心职责：
// - 展示话题封面和话题符号标识
// - 根据更新状态呈现未读红点
struct TopicAvatarView: View {
    let assetName: String
    let showUnreadDot: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s5, height: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s5)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                .overlay {
                    Text("#")
                        .font(.system(size: MHBTheme.IconSize.small, weight: .black))
                        .foregroundStyle(.white)
                        .padding(MHBTheme.Spacing.s1)
                        .background(.black.opacity(0.24), in: Circle())
                }

            if showUnreadDot {
                Circle()
                    .fill(MHBTheme.ColorToken.danger.color)
                    .frame(width: MHBTheme.Spacing.s2, height: MHBTheme.Spacing.s2)
                    .overlay {
                        Circle().stroke(.white, lineWidth: 1)
                    }
            }
        }
    }
}
