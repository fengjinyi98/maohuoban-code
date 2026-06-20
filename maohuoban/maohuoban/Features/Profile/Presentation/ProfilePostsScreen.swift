import SwiftUI
import MaohuobanDesignSystem

// ProfilePostsScreen 我的动态列表页
// 核心职责：
// - 展示当前用户发布的动态 Feed 流
// - 组合通用 Feed 卡片和互动状态能力
struct ProfilePostsScreen: View {
    let interactionStore: FeedInteractionStore
    let onOpenRoute: (ProfileRoute) -> Void

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            FeedList(
                cards: ProfileMockFeed.cards,
                interactionStore: interactionStore,
                topContentInset: MHBTheme.Spacing.s4,
                accessibilityIdentifierPrefix: "profile.posts.feed.card",
                topTrailingAction: .delete,
                showsRecommendationReason: false,
                detailRoute: { card in
                    ProfileRoute.feedDetail(postID: card.postID)
                },
                onOpenDetail: openDetail(route:)
            )
            .accessibilityIdentifier("profile.posts.feedList")
        }
        .navigationTitle("我的动态")
        .navigationBarTitleDisplayMode(.inline)
        .background(MHBInteractivePopGestureRestorer())
    }

    private func openDetail(route: ProfileRoute) {
        switch route {
        case .feedDetail:
            onOpenRoute(route)
        case .posts,
             .petAlbumList:
            break
        }
    }
}
