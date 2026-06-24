import SwiftUI
import MaohuobanDesignSystem

// TopicDetailScreen 话题详情页
// 核心职责：
// - 展示单个话题的头部信息、关注状态和话题内容流
// - 复用通用 Feed 基础设施承载话题 UGC 列表
struct TopicDetailScreen<FeedDetailRoute: Hashable, ComposerRoute: Hashable>: View {
    let topicID: String
    let store: TopicStore
    let feedDetailRoute: (FeedItem) -> FeedDetailRoute
    let composerRoute: (TopicSummary) -> ComposerRoute

    var body: some View {
        if let topic = store.topic(id: topicID) {
            TopicDetailLoadedScreen(
                topic: topic,
                feedItems: store.topicFeedItems(topicID: topic.id),
                isFollowed: store.isFollowed(topicID: topic.id),
                feedDetailRoute: feedDetailRoute,
                composerRoute: composerRoute,
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
// - 组合话题头部、Feed 内容流和底部参与入口
private struct TopicDetailLoadedScreen<FeedDetailRoute: Hashable, ComposerRoute: Hashable>: View {
    let topic: TopicSummary
    let feedItems: [FeedItem]
    let isFollowed: Bool
    let feedDetailRoute: (FeedItem) -> FeedDetailRoute
    let composerRoute: (TopicSummary) -> ComposerRoute
    let onToggleFollow: () -> Void
    @State private var interactionStore: FeedInteractionStore

    init(
        topic: TopicSummary,
        feedItems: [FeedItem],
        isFollowed: Bool,
        feedDetailRoute: @escaping (FeedItem) -> FeedDetailRoute,
        composerRoute: @escaping (TopicSummary) -> ComposerRoute,
        onToggleFollow: @escaping () -> Void
    ) {
        self.topic = topic
        self.feedItems = feedItems
        self.isFollowed = isFollowed
        self.feedDetailRoute = feedDetailRoute
        self.composerRoute = composerRoute
        self.onToggleFollow = onToggleFollow
        _interactionStore = State(initialValue: FeedInteractionStore(cards: feedItems))
    }

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                if feedItems.isEmpty {
                    TopicDetailEmptyContent(
                        topic: topic,
                        isFollowed: isFollowed,
                        onToggleFollow: onToggleFollow
                    )
                } else {
                    FeedList(
                        cards: feedItems,
                        interactionStore: interactionStore,
                        topContentInset: MHBTheme.Spacing.s4,
                        accessibilityIdentifierPrefix: "topics.detail.feed.card",
                        detailRoute: feedDetailRoute
                    ) {
                        TopicDetailFeedHeader(
                            topic: topic,
                            isFollowed: isFollowed,
                            onToggleFollow: onToggleFollow
                        )
                    }
                }

                TopicDetailBottomAction(
                    route: composerRoute(topic),
                    bottomInset: bottomInset
                )
                .zIndex(2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationTitle(topic.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("topics.detail.\(topic.id)")
    }
}

// TopicDetailFeedHeader 话题详情 Feed 头部
// 核心职责：
// - 保持话题信息和内容流处于同一滚动上下文
// - 为通用 Feed 列表提供轻量分区标题
private struct TopicDetailFeedHeader: View {
    let topic: TopicSummary
    let isFollowed: Bool
    let onToggleFollow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
            TopicDetailHeroSection(
                topic: topic,
                isFollowed: isFollowed,
                onToggleFollow: onToggleFollow
            )

            Text("最新动态")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
    }
}

// TopicDetailHeroSection 话题详情头部
// 核心职责：
// - 展示话题封面、简介、统计和关注按钮
// - 作为非卡片式页面头部融入 Feed 滚动流
private struct TopicDetailHeroSection: View {
    let topic: TopicSummary
    let isFollowed: Bool
    let onToggleFollow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
                TopicAvatarView(
                    assetName: topic.thumbnailAssetName,
                    showUnreadDot: topic.todayPostCount > 0
                )

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
    }

    private var followButtonBackground: Color {
        isFollowed ? MHBTheme.ColorToken.separatorSoft.color : MHBTheme.ColorToken.primary.color
    }
}

// TopicDetailStatPill 话题详情统计标签
// 核心职责：
// - 展示话题动态数、关注数和今日更新数
// - 保持头部统计区域轻量分组
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

// TopicDetailBottomAction 话题详情底部操作
// 核心职责：
// - 提供进入发布草稿并默认选中当前话题的入口
// - 使用基础设施底部 CTA 组件保持统一体验
private struct TopicDetailBottomAction<Route: Hashable>: View {
    let route: Route
    let bottomInset: CGFloat

    var body: some View {
        MHBBottomFloatingCTA(
            title: "参与讨论",
            systemImage: "square.and.pencil",
            route: route,
            bottomInset: bottomInset
        )
    }
}

// TopicDetailEmptyContent 话题详情空内容
// 核心职责：
// - 在新建话题没有动态时保留话题头部
// - 使用统一滚动容器展示空态
private struct TopicDetailEmptyContent: View {
    let topic: TopicSummary
    let isFollowed: Bool
    let onToggleFollow: () -> Void

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                TopicDetailHeroSection(
                    topic: topic,
                    isFollowed: isFollowed,
                    onToggleFollow: onToggleFollow
                )

                TopicDetailEmptyFeedState(topicName: topic.displayName)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s3)
            .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8)
        }
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
