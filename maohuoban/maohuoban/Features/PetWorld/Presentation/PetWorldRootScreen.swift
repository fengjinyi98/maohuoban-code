import SwiftUI
import MaohuobanDesignSystem

// PetWorldRootScreen 宠物世界 Tab 根视图
// 核心职责：
// - 保留宠物世界 Tab 的空页面入口
// - 在系统导航栏位置承载频道 tab 和搜索入口
struct PetWorldRootScreen: View {
    let topicStore: TopicStore
    @State private var selectedTab = PetWorldNavigationTab.recommended
    @State private var lastFeedScrollOffset: CGFloat = 0
    @State private var isNavigationHeaderHidden = false
    @State private var feedInteractionStore = FeedInteractionStore(cards: PetWorldMockFeed.cards)

    init(topicStore: TopicStore = TopicStore()) {
        self.topicStore = topicStore
    }

    var body: some View {
        ZStack(alignment: .top) {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            FeedList(
                cards: PetWorldMockFeed.cards,
                interactionStore: feedInteractionStore,
                topContentInset: PetWorldRootLayout.contentTopInset,
                accessibilityIdentifierPrefix: "petWorld.feed.card",
                detailRoute: { card in
                    PetWorldRoute.feedDetail(postID: card.postID)
                },
                onMoreAction: handleFeedMoreAction(postID:action:),
                onScrollOffsetChange: handleFeedScrollOffset(_:),
                onScrollPhaseChange: handleFeedScrollPhase(_:)
            )
                .accessibilityIdentifier("petWorld.root")

            PetWorldNavigationHeader(selection: $selectedTab)
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.top, MHBTheme.Spacing.s1)
                .offset(
                    y: isNavigationHeaderHidden
                        ? -PetWorldRootLayout.navigationHiddenOffset
                        : 0
                )
                .opacity(isNavigationHeaderHidden ? 0 : 1)
                .allowsHitTesting(!isNavigationHeaderHidden)
                .animation(
                    PetWorldRootLayout.navigationVisibilityAnimation(isHidden: isNavigationHeaderHidden),
                    value: isNavigationHeaderHidden
                )
                .zIndex(1)
        }
        .safeAreaInset(edge: .bottom) {
            PetWorldPublishEntryButton()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: PetWorldRoute.self) { route in
            switch route {
            case .feedDetail(let postID):
                PetWorldFeedDetailScreen(
                    postID: postID,
                    interactionStore: feedInteractionStore
                )
            }
        }
        .navigationDestination(for: TopicRoute.self) { route in
            TopicRouteDestinationScreen(route: route, store: topicStore)
                .toolbar(.visible, for: .navigationBar)
        }
    }

    private func handleFeedScrollOffset(_ offset: CGFloat) {
        let delta = offset - lastFeedScrollOffset
        lastFeedScrollOffset = offset

        guard abs(delta) >= PetWorldRootLayout.scrollDirectionThreshold else {
            return
        }

        if offset <= PetWorldRootLayout.scrollTopRevealOffset {
            setNavigationHeaderHidden(false)
            return
        }

        if delta > 0, offset > PetWorldRootLayout.scrollHideStartOffset {
            setNavigationHeaderHidden(true)
        } else if delta < 0 {
            setNavigationHeaderHidden(false)
        }
    }

    private func handleFeedScrollPhase(_ phase: ScrollPhase) {
        guard phase == .idle else {
            return
        }

        setNavigationHeaderHidden(false)
    }

    private func setNavigationHeaderHidden(_ isHidden: Bool) {
        guard isNavigationHeaderHidden != isHidden else {
            return
        }

        withAnimation(PetWorldRootLayout.navigationVisibilityAnimation(isHidden: isHidden)) {
            isNavigationHeaderHidden = isHidden
        }
    }

    private func handleFeedMoreAction(
        postID: String,
        action: FeedMoreAction
    ) {
        switch action {
        case .dislike:
            break
        case .report:
            break
        case .delete:
            break
        }
    }
}

// PetWorldPublishEntryButton 宠物世界发布入口
// 核心职责：
// - 在快速 UI 阶段提供进入发布话题选择原型的入口
// - 使用系统导航值进入发布草稿页面
private struct PetWorldPublishEntryButton: View {
    var body: some View {
        HStack {
            Spacer()

            NavigationLink(value: TopicRoute.composer(seedTopicID: nil)) {
                Label("发布", systemImage: "square.and.pencil")
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .frame(height: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s3)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.trailing, MHBTheme.Spacing.s5)
            .padding(.bottom, MHBTheme.Spacing.s2)
        }
    }
}

// PetWorldRootLayout 宠物世界根布局配置
// 核心职责：
// - 统一自定义导航头部与滚动内容的垂直关系
// - 让 feed 首屏内容避开顶层 Liquid Glass 控件
private enum PetWorldRootLayout {
    static let navigationControlHeight: CGFloat = MHBTheme.Spacing.s8 + MHBTheme.Spacing.s4
    static let navigationBottomGap: CGFloat = MHBTheme.Spacing.s4
    static let scrollDirectionThreshold: CGFloat = MHBTheme.Spacing.s1
    static let scrollHideStartOffset: CGFloat = MHBTheme.Spacing.s8
    static let scrollTopRevealOffset: CGFloat = MHBTheme.Spacing.s2
    static let navigationHideAnimation = Animation.smooth(duration: 0.24, extraBounce: 0)
    static let navigationRevealAnimation = Animation.interactiveSpring(
        response: 0.34,
        dampingFraction: 0.64,
        blendDuration: 0.12
    )
    static let contentTopInset = MHBTheme.Spacing.s1 + navigationControlHeight + navigationBottomGap
    static let navigationHiddenOffset = MHBTheme.Spacing.s1 + navigationControlHeight + navigationBottomGap

    // navigationVisibilityAnimation 顶部导航显隐动画
    // 核心职责：
    // - 为隐藏动作提供干净收起动画
    // - 为出现动作提供克制的弹性回位动画
    static func navigationVisibilityAnimation(isHidden: Bool) -> Animation {
        isHidden ? navigationHideAnimation : navigationRevealAnimation
    }
}
