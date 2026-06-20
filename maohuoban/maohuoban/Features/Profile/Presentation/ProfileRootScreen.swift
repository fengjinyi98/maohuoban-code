import SwiftUI
import MaohuobanDesignSystem

// ProfileRootScreen 我的 Tab 根视图
// 核心职责：
// - 作为"我的"Tab NavigationStack 的根内容
// - 承载个人信息概览和系统导航栏工具入口
struct ProfileRootScreen: View {
    let topicStore: TopicStore
    let onLogout: () -> Void
    @State private var feedInteractionStore = FeedInteractionStore(cards: ProfileMockFeed.cards)

    init(
        topicStore: TopicStore = TopicStore(),
        onLogout: @escaping () -> Void
    ) {
        self.topicStore = topicStore
        self.onLogout = onLogout
    }

    var body: some View {
        ScrollView {
            VStack(spacing: MHBTheme.Spacing.s3) {
                ProfileAccountSummarySection(
                    profile: ProfileAccountSummary.mock,
                    postsRoute: .posts
                )

                ProfileQuickEntriesSection(items: ProfileQuickEntryItem.mockItems) { item in
                    print("Tapped quick entry: \(item.title)")
                } routeForItem: { item in
                    quickEntryRoute(for: item)
                }

                ProfileFAQBanner {
                    print("Tapped FAQ banner")
                }

                ProfileBadgesSection(badges: ProfileBadge.mockBadges) {
                    print("Tapped badges header")
                } onBadgeClick: { badge in
                    print("Tapped badge: \(badge.title)")
                }

                ProfileFollowedTopicsSection(
                    topics: Array(topicStore.followedTopics.prefix(8)),
                    headerRoute: .followedList
                ) { topic in
                    .detail(topicID: topic.id)
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s3)
            .padding(.top, MHBTheme.Spacing.s3)
            .padding(.bottom, MHBTheme.Spacing.s6)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .accessibilityIdentifier("profile.scrollView")
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {} label: {
                    Image(systemName: "sparkles")
                }
                .accessibilityLabel("毛球")
                .accessibilityIdentifier("profile.maoqiuButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("设置")
                .accessibilityIdentifier("profile.settingsButton")
            }
        }
        .navigationDestination(for: ProfileRoute.self) { route in
            switch route {
            case .posts:
                ProfilePostsScreen(interactionStore: feedInteractionStore)
            case .feedDetail(let postID):
                ProfileFeedDetailScreen(
                    postID: postID,
                    interactionStore: feedInteractionStore
                )
            case .petAlbumList:
                PetAlbumListScreen()
            }
        }
        .navigationDestination(for: TopicRoute.self) { route in
            TopicRouteDestinationScreen(route: route, store: topicStore)
        }
    }

    private func quickEntryRoute(for item: ProfileQuickEntryItem) -> ProfileRoute? {
        switch item.id {
        case "petAlbum":
            return .petAlbumList
        default:
            return nil
        }
    }
}
