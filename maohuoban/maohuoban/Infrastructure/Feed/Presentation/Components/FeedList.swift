import SwiftUI
import MaohuobanDesignSystem

// FeedList 通用 UGC Feed 列表
// 核心职责：
// - 承载帖子卡片纵向滚动布局
// - 为不同页面提供统一卡片、更多菜单和滚动事件能力
struct FeedList<DetailRoute: Hashable, Header: View>: View {
    let cards: [FeedItem]
    let interactionStore: FeedInteractionStore
    let topContentInset: CGFloat
    let accessibilityIdentifierPrefix: String
    let topTrailingAction: FeedCardTopTrailingAction
    let showsRecommendationReason: Bool
    let detailRoute: (FeedItem) -> DetailRoute
    let onOpenDetail: ((DetailRoute) -> Void)?
    let onMoreAction: (String, FeedMoreAction) -> Void
    let onScrollOffsetChange: (CGFloat) -> Void
    let onScrollPhaseChange: (ScrollPhase) -> Void
    @ViewBuilder let header: () -> Header

    @State private var presentedMoreMenuPostID: String?
    @State private var moreButtonFrames: [String: CGRect] = [:]

    init(
        cards: [FeedItem],
        interactionStore: FeedInteractionStore,
        topContentInset: CGFloat,
        accessibilityIdentifierPrefix: String = "feed.card",
        topTrailingAction: FeedCardTopTrailingAction = .moreMenu,
        showsRecommendationReason: Bool = true,
        detailRoute: @escaping (FeedItem) -> DetailRoute,
        onOpenDetail: ((DetailRoute) -> Void)? = nil,
        onMoreAction: @escaping (String, FeedMoreAction) -> Void = { _, _ in },
        onScrollOffsetChange: @escaping (CGFloat) -> Void = { _ in },
        onScrollPhaseChange: @escaping (ScrollPhase) -> Void = { _ in },
        @ViewBuilder header: @escaping () -> Header
    ) {
        self.cards = cards
        self.interactionStore = interactionStore
        self.topContentInset = topContentInset
        self.accessibilityIdentifierPrefix = accessibilityIdentifierPrefix
        self.topTrailingAction = topTrailingAction
        self.showsRecommendationReason = showsRecommendationReason
        self.detailRoute = detailRoute
        self.onOpenDetail = onOpenDetail
        self.onMoreAction = onMoreAction
        self.onScrollOffsetChange = onScrollOffsetChange
        self.onScrollPhaseChange = onScrollPhaseChange
        self.header = header
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                MHBScreenScrollView(showsIndicators: false) {
                    LazyVStack(spacing: MHBTheme.Spacing.s8) {
                        header()

                        ForEach(cards) { card in
                            FeedCard(
                                card: card,
                                interactionState: interactionStore.interactionState(for: card),
                                detailRoute: detailRoute(card),
                                topTrailingAction: topTrailingAction,
                                showsRecommendationReason: showsRecommendationReason,
                                onOpenDetail: onOpenDetail,
                                onToggleLike: {
                                    interactionStore.toggleLike(postID: card.postID)
                                },
                                onMoreTap: {
                                    handleTopTrailingAction(postID: card.postID)
                                }
                            )
                            .accessibilityIdentifier("\(accessibilityIdentifierPrefix).\(card.id)")
                        }
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .padding(.top, topContentInset)
                    .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8)
                }
                .onPreferenceChange(FeedMoreButtonFramePreferenceKey.self) { frames in
                    moreButtonFrames = frames
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(geometry.contentOffset.y, 0)
                } action: { _, offset in
                    onScrollOffsetChange(offset)
                }
                .onScrollPhaseChange { _, phase in
                    if phase != .idle {
                        dismissMoreMenu()
                    }
                    onScrollPhaseChange(phase)
                }

                if presentedMoreMenuPostID != nil {
                    MHBOutsideTapDismissLayer(onDismiss: dismissMoreMenu)
                        .zIndex(1)
                }

                FeedMoreMenuOverlay(
                    isPresented: presentedMoreMenuPostID != nil,
                    containerSize: proxy.size,
                    buttonFrame: presentedMoreMenuButtonFrame,
                    onAction: handleMoreMenuAction
                )
                .zIndex(2)
            }
            .coordinateSpace(name: FeedCoordinateSpace.name)
        }
    }

    private var presentedMoreMenuButtonFrame: CGRect {
        guard let presentedMoreMenuPostID else {
            return .zero
        }

        return moreButtonFrames[presentedMoreMenuPostID] ?? .zero
    }

    private func toggleMoreMenu(postID: String) {
        withAnimation(.snappy(duration: 0.22)) {
            presentedMoreMenuPostID = presentedMoreMenuPostID == postID ? nil : postID
        }
    }

    private func handleTopTrailingAction(postID: String) {
        guard let directAction = topTrailingAction.directAction else {
            toggleMoreMenu(postID: postID)
            return
        }

        dismissMoreMenu()
        onMoreAction(postID, directAction)
    }

    private func dismissMoreMenu() {
        guard presentedMoreMenuPostID != nil else {
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            presentedMoreMenuPostID = nil
        }
    }

    private func handleMoreMenuAction(_ action: FeedMoreAction) {
        guard let postID = presentedMoreMenuPostID else {
            return
        }

        dismissMoreMenu()
        onMoreAction(postID, action)
    }

}

extension FeedList where Header == EmptyView {
    init(
        cards: [FeedItem],
        interactionStore: FeedInteractionStore,
        topContentInset: CGFloat,
        accessibilityIdentifierPrefix: String = "feed.card",
        topTrailingAction: FeedCardTopTrailingAction = .moreMenu,
        showsRecommendationReason: Bool = true,
        detailRoute: @escaping (FeedItem) -> DetailRoute,
        onOpenDetail: ((DetailRoute) -> Void)? = nil,
        onMoreAction: @escaping (String, FeedMoreAction) -> Void = { _, _ in },
        onScrollOffsetChange: @escaping (CGFloat) -> Void = { _ in },
        onScrollPhaseChange: @escaping (ScrollPhase) -> Void = { _ in }
    ) {
        self.init(
            cards: cards,
            interactionStore: interactionStore,
            topContentInset: topContentInset,
            accessibilityIdentifierPrefix: accessibilityIdentifierPrefix,
            topTrailingAction: topTrailingAction,
            showsRecommendationReason: showsRecommendationReason,
            detailRoute: detailRoute,
            onOpenDetail: onOpenDetail,
            onMoreAction: onMoreAction,
            onScrollOffsetChange: onScrollOffsetChange,
            onScrollPhaseChange: onScrollPhaseChange
        ) {
            EmptyView()
        }
    }
}
