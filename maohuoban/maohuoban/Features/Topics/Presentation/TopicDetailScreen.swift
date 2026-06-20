import SwiftUI
import MaohuobanDesignSystem

// TopicDetailScreen 话题详情页
// 核心职责：
// - 展示单个话题的头部信息、关注状态和话题内容流
// - 提供进入发布草稿并参与当前话题的入口
struct TopicDetailScreen: View {
    let topicID: String
    let store: TopicStore

    var body: some View {
        if let topic = store.topic(id: topicID) {
            TopicDetailLoadedScreen(
                topic: topic,
                posts: store.topicPosts(topicID: topic.id),
                isFollowed: store.isFollowed(topicID: topic.id),
                onToggleFollow: {
                    store.toggleFollow(topicID: topic.id)
                }
            )
        } else {
            TopicDetailMissingScreen()
        }
    }
}

// TopicDetailLoadedScreen 话题详情已加载页
// 核心职责：
// - 组合话题头部、内容流和底部参与入口
private struct TopicDetailLoadedScreen: View {
    let topic: TopicSummary
    let posts: [TopicPostPreview]
    let isFollowed: Bool
    let onToggleFollow: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                TopicDetailHeroSection(
                    topic: topic,
                    isFollowed: isFollowed,
                    onToggleFollow: onToggleFollow
                )

                if posts.isEmpty {
                    TopicDetailEmptyFeedState(topicName: topic.displayName)
                } else {
                    TopicDetailFeedSection(posts: posts)
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s3)
            .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle(topic.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            TopicDetailBottomAction(topicID: topic.id)
        }
        .accessibilityIdentifier("topics.detail.\(topic.id)")
    }
}

// TopicDetailHeroSection 话题详情头部
// 核心职责：
// - 展示话题封面、简介、统计和关注按钮
private struct TopicDetailHeroSection: View {
    let topic: TopicSummary
    let isFollowed: Bool
    let onToggleFollow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
                TopicAvatarView(assetName: topic.thumbnailAssetName, showUnreadDot: topic.todayPostCount > 0)

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(topic.displayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(2)

                    Text(topic.updateText)
                        .font(MHBTheme.Typography.footnote)
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    onToggleFollow()
                } label: {
                    Text(isFollowed ? "已关注" : "关注")
                        .font(MHBTheme.Typography.footnote.weight(.semibold))
                        .foregroundStyle(isFollowed ? MHBTheme.ColorToken.labelSecondary.color : .white)
                        .padding(.horizontal, MHBTheme.Spacing.s4)
                        .frame(height: MHBTheme.Spacing.s8)
                        .background(followButtonBackground, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Text(topic.description)
                .font(MHBTheme.Typography.body)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: MHBTheme.Spacing.s2) {
                TopicDetailStatPill(title: "动态", value: "\(topic.postCount)")
                TopicDetailStatPill(title: "关注", value: "\(topic.followerCount)")
                TopicDetailStatPill(title: "今日", value: "\(topic.todayPostCount)")
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
    }

    private var followButtonBackground: Color {
        isFollowed ? MHBTheme.ColorToken.separatorSoft.color : MHBTheme.ColorToken.primary.color
    }
}

// TopicDetailStatPill 话题详情统计标签
// 核心职责：
// - 展示话题动态数、关注数和今日更新数
private struct TopicDetailStatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s1 / 2) {
            Text(value)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text(title)
                .font(MHBTheme.Typography.section)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MHBTheme.Spacing.s2)
        .background(MHBTheme.ColorToken.separatorSoft.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}

// TopicDetailFeedSection 话题详情内容流
// 核心职责：
// - 展示话题下的帖子预览卡片列表
private struct TopicDetailFeedSection: View {
    let posts: [TopicPostPreview]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("最新动态")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            ForEach(posts) { post in
                TopicPostPreviewCard(post: post)
            }
        }
    }
}

// TopicPostPreviewCard 话题帖子预览卡片
// 核心职责：
// - 渲染话题详情页中的轻量帖子预览
private struct TopicPostPreviewCard: View {
    let post: TopicPostPreview

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            TopicPostPreviewHeader(
                authorName: post.authorName,
                avatarAssetName: post.avatarAssetName,
                publishedText: post.publishedText
            )

            Text(post.caption)
                .font(MHBTheme.Typography.body)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .fixedSize(horizontal: false, vertical: true)

            Image(post.mediaAssetName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))

            TopicPostPreviewActions(
                likeCountText: post.likeCountText,
                commentCountText: post.commentCountText
            )
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
    }
}

// TopicPostPreviewHeader 话题帖子预览头部
// 核心职责：
// - 展示作者头像、昵称和发布时间
private struct TopicPostPreviewHeader: View {
    let authorName: String
    let avatarAssetName: String
    let publishedText: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Image(avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: MHBTheme.Spacing.s8, height: MHBTheme.Spacing.s8)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1 / 2) {
                Text(authorName)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(publishedText)
                    .font(MHBTheme.Typography.section)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer()

            Image(systemName: "ellipsis")
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
    }
}

// TopicPostPreviewActions 话题帖子预览互动区
// 核心职责：
// - 展示点赞、评论和分享入口占位
private struct TopicPostPreviewActions: View {
    let likeCountText: String
    let commentCountText: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            Label(likeCountText, systemImage: "heart")
            Label(commentCountText, systemImage: "bubble.right")
            Spacer()
            Image(systemName: "square.and.arrow.up")
        }
        .font(MHBTheme.Typography.footnote)
        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
    }
}

// TopicDetailBottomAction 话题详情底部操作
// 核心职责：
// - 提供进入发布草稿并默认选中当前话题的入口
private struct TopicDetailBottomAction: View {
    let topicID: String

    var body: some View {
        NavigationLink(value: TopicRoute.composer(seedTopicID: topicID)) {
            Label("参与讨论", systemImage: "square.and.pencil")
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, MHBTheme.Spacing.s5)
                .frame(height: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s4)
                .background(MHBTheme.ColorToken.primary.color, in: Capsule())
                .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.vertical, MHBTheme.Spacing.s2)
    }
}

// TopicDetailEmptyFeedState 话题详情内容空态
// 核心职责：
// - 展示新建话题暂无内容的状态
private struct TopicDetailEmptyFeedState: View {
    let topicName: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "text.bubble")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)

            Text("\(topicName) 还没有动态")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("发布时选择这个话题后，会沉淀为后续分类、推荐和 RAG 的结构化信号。")
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(MHBTheme.Spacing.s6)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
    }
}

// TopicDetailMissingScreen 话题详情缺失页
// 核心职责：
// - 在路由目标不存在时提供可恢复的空态
private struct TopicDetailMissingScreen: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "number")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text("话题不存在")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("这个话题可能尚未创建或已被移除。")
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .padding(MHBTheme.Spacing.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("话题")
    }
}
