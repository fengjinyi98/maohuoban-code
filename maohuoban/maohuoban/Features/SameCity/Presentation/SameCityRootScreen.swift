import SwiftUI
import UIKit
import MaohuobanDesignSystem

// SameCityRootScreen 同城 Tab 根视图
// 核心职责：
// - 作为同城 Tab NavigationStack 的根内容
// - 在系统 toolbar 中承载城市和搜索入口
// - 展示同城业务金刚区
// - 展示同城商品 Feed 并提供底部发布入口
struct SameCityRootScreen: View {
    let topicStore: TopicStore
    let tabState: MHBAppTabState
    let currentUserStore: CurrentUserStore
    @State private var feedInteractionStore = FeedInteractionStore(cards: SameCityCommodityMockFeed.items.map(\.feedItem))
    @State private var presentedMoreMenuPostID: String?
    @State private var moreButtonFrames: [String: CGRect] = [:]

    init(
        topicStore: TopicStore = TopicStore(),
        tabState: MHBAppTabState = MHBAppTabState(),
        currentUserStore: CurrentUserStore
    ) {
        self.topicStore = topicStore
        self.tabState = tabState
        self.currentUserStore = currentUserStore
    }

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    MHBScreenScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: SameCityRootLayout.sectionSpacing) {
                            SameCityServiceMatrix()

                            SameCityLocalFeedSection(
                                items: SameCityCommodityMockFeed.items,
                                interactionStore: feedInteractionStore,
                                detailRoute: { item in
                                    SameCityRoute.commodityDetail(postID: item.feedItem.postID)
                                },
                                onMoreTap: handleCommodityMoreTap(_:)
                            )
                        }
                        .padding(.horizontal, MHBTheme.Spacing.s3)
                        .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8)
                    }
                    .onPreferenceChange(FeedMoreButtonFramePreferenceKey.self) { frames in
                        guard let resolvedFrames = FeedMoreButtonFrameStateResolver.resolvedUpdate(
                            current: moreButtonFrames,
                            incoming: frames
                        ) else {
                            return
                        }

                        moreButtonFrames = resolvedFrames
                    }
                    .onScrollPhaseChange { _, phase in
                        if phase != .idle {
                            dismissCommodityMoreMenu()
                        }
                    }
                    if presentedMoreMenuPostID != nil {
                        MHBOutsideTapDismissLayer(onDismiss: dismissCommodityMoreMenu)
                            .zIndex(3)
                    }

                    FeedMoreMenuOverlay(
                        isPresented: presentedMoreMenuPostID != nil,
                        containerSize: proxy.size,
                        buttonFrame: presentedMoreMenuButtonFrame,
                        onAction: handleCommodityMoreMenuAction(_:)
                    )
                    .zIndex(4)
                }
                .coordinateSpace(name: FeedCoordinateSpace.name)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SameCityLocationButton(city: SameCityRootLayout.currentCity)
            }

            ToolbarItem(placement: .topBarTrailing) {
                SameCitySearchButton(
                    route: SameCityRoute.search(.sameCity(city: SameCityRootLayout.currentCity))
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            SameCityPublishEntryButton(route: SameCityRoute.publishEvent(publishContext))
        }
        .navigationDestination(for: SameCityRoute.self) { route in
            switch route {
            case .search(let context):
                SearchScreen(context: context)
            case .publishEvent(let context):
                PublishEventComposerScreen(context: context)
            case .commodityDetail(let postID):
                SameCityCommodityDetailScreen(
                    postID: postID,
                    currentUserStore: currentUserStore,
                    interactionStore: feedInteractionStore,
                    topicRoute: { topicName in
                        SameCityRoute.topicDetail(topicID: TopicIdentifier.id(for: topicName))
                    },
                    onOpenTopicRoute: { route in
                        tabState.appendSameCityRoute(route)
                    },
                    growthRecordRoute: { postID in
                        SameCityRoute.growthRecord(postID: postID)
                    },
                    onOpenGrowthRecordRoute: { route in
                        tabState.appendSameCityRoute(route)
                    }
                )
            case .growthRecord(let postID):
                if let archive = SameCityCommodityMockDetail.detail(for: postID)?.growthRecordCard?.archive {
                    SameCityCommodityGrowthRecordScreen(archive: archive)
                } else {
                    SameCityCommodityGrowthRecordMissingScreen()
                }
            case .topicDetail(let topicID):
                TopicDetailScreen(
                    topicID: topicID,
                    store: topicStore,
                    feedDetailRoute: { item in
                        SameCityRoute.topicFeedDetail(postID: item.postID)
                    },
                    composerRoute: { topic in
                        SameCityRoute.publishEvent(
                            PublishEntryContext(
                                source: .sameCity,
                                city: SameCityRootLayout.currentCity,
                                localEntityName: "\(SameCityRootLayout.currentCity)同城",
                                seedTopicID: topic.id,
                                seedTopicName: topic.name
                            )
                        )
                    }
                )
            case .topicFeedDetail(let postID):
                SameCityCommodityDetailScreen(
                    postID: postID,
                    currentUserStore: currentUserStore,
                    interactionStore: feedInteractionStore,
                    topicRoute: { topicName in
                        SameCityRoute.topicDetail(topicID: TopicIdentifier.id(for: topicName))
                    },
                    onOpenTopicRoute: { route in
                        tabState.appendSameCityRoute(route)
                    },
                    growthRecordRoute: { postID in
                        SameCityRoute.growthRecord(postID: postID)
                    },
                    onOpenGrowthRecordRoute: { route in
                        tabState.appendSameCityRoute(route)
                    }
                )
            }
        }
        .accessibilityIdentifier("sameCity.root")
    }

    private var publishContext: PublishEntryContext {
        PublishEntryContext(
            source: .sameCity,
            city: SameCityRootLayout.currentCity,
            localEntityName: "\(SameCityRootLayout.currentCity)同城"
        )
    }

    private var presentedMoreMenuButtonFrame: CGRect {
        guard let presentedMoreMenuPostID else {
            return .zero
        }

        return moreButtonFrames[presentedMoreMenuPostID] ?? .zero
    }

    private func handleCommodityMoreTap(_ item: SameCityCommodityFeedItem) {
        toggleCommodityMoreMenu(postID: item.feedItem.postID)
    }

    private func toggleCommodityMoreMenu(postID: String) {
        withAnimation(.snappy(duration: 0.22)) {
            presentedMoreMenuPostID = FeedMoreMenuPresentationStateResolver.toggledPostID(
                current: presentedMoreMenuPostID,
                postID: postID
            )
        }
    }

    private func dismissCommodityMoreMenu() {
        guard presentedMoreMenuPostID != nil else {
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            presentedMoreMenuPostID = nil
        }
    }

    private func handleCommodityMoreMenuAction(_ action: FeedMoreAction) {
        guard let postID = presentedMoreMenuPostID else {
            return
        }

        dismissCommodityMoreMenu()
        handleCommodityMoreAction(postID: postID, action: action)
    }

    private func handleCommodityMoreAction(
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
        case .removeFromFavoriteFolder:
            break
        }
    }
}
