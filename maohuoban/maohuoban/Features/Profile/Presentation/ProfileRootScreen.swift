import SwiftUI
import MaohuobanDesignSystem

// ProfileRootScreen 我的 Tab 根视图
// 核心职责：
// - 作为"我的"Tab NavigationStack 的根内容
// - 承载个人信息概览和系统导航栏工具入口
struct ProfileRootScreen: View {
    let topicStore: TopicStore
    let tabState: MHBAppTabState
    let currentUserID: String?
    let onLogout: () -> Void
    @State private var feedInteractionStore = FeedInteractionStore(cards: ProfileMockFeed.cards)

    init(
        topicStore: TopicStore = TopicStore(),
        tabState: MHBAppTabState = MHBAppTabState(),
        currentUserID: String? = nil,
        onLogout: @escaping () -> Void
    ) {
        self.topicStore = topicStore
        self.tabState = tabState
        self.currentUserID = currentUserID
        self.onLogout = onLogout
    }

    var body: some View {
        ScrollView {
            VStack(spacing: MHBTheme.Spacing.s3) {
                ProfileAccountSummarySection(
                    profile: ProfileAccountSummary.mock,
                    onOpenPosts: openPosts
                )

                ProfileQuickEntriesSection(items: ProfileQuickEntryItem.mockItems) { item in
                    print("Tapped quick entry: \(item.title)")
                } routeForItem: { item in
                    quickEntryRoute(for: item)
                }

                ProfileFAQBanner {
                    print("Tapped FAQ banner")
                }

                ProfileBadgesSection(badges: ProfileBadge.mockBadges.filter(\.isEarned)) {
                    tabState.appendProfileRoute(.badges(selectedBadgeID: nil))
                } onBadgeClick: { badge in
                    tabState.appendProfileRoute(.badges(selectedBadgeID: badge.id))
                }

                ProfileFollowedTopicsSection(
                    topics: Array(topicStore.followedTopics.prefix(8)),
                    headerRoute: ProfileRoute.followedTopics
                ) { topic in
                    ProfileRoute.topicDetail(topicID: topic.id)
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
            case .myPets:
                PetManagementScreen(
                    pets: PetManagementPet.mockPets,
                    onOpenPet: { pet in
                        tabState.appendProfileRoute(
                            .editPetProfile(
                                PetManagementPet.editContext(
                                    selectedPet: pet,
                                    pets: PetManagementPet.mockPets
                                )
                            )
                        )
                    },
                    onAddPet: {
                        tabState.appendProfileRoute(.createPet)
                    }
                )
            case .createPet:
                PetProfileAddScreen(
                    currentUserID: currentUserID,
                    onCreated: { _ in }
                )
            case .editPetProfile(let context):
                PetProfileEditScreen(
                    context: context,
                    currentUserID: currentUserID
                )
            case .posts:
                ProfilePostsScreen(
                    interactionStore: feedInteractionStore
                )
            case .badges(let selectedBadgeID):
                ProfileBadgesScreen(
                    badges: ProfileBadge.mockBadges,
                    initialSelectedBadgeID: selectedBadgeID
                )
            case .feedDetail(let postID):
                ProfileFeedDetailScreen(
                    postID: postID,
                    interactionStore: feedInteractionStore,
                    onOpenTopicRoute: { route in
                        tabState.appendProfileRoute(route)
                    }
                )
            case .petAlbumList:
                PetAlbumListScreen { album in
                    ProfileRoute.petAlbumDetail(albumID: album.id)
                }
            case .petAlbumDetail(let albumID):
                PetAlbumDetailScreen(albumID: albumID)
            case .followedTopics:
                TopicFollowedListScreen(store: topicStore) { topic in
                    ProfileRoute.topicDetail(topicID: topic.id)
                }
            case .topicDetail(let topicID):
                TopicDetailScreen(
                    topicID: topicID,
                    store: topicStore,
                    feedDetailRoute: { item in
                        ProfileRoute.topicFeedDetail(postID: item.postID)
                    },
                    composerRoute: { topicID in
                        ProfileRoute.topicComposer(seedTopicID: topicID)
                    }
                )
            case .topicFeedDetail(let postID):
                ProfileFeedDetailScreen(
                    postID: postID,
                    interactionStore: feedInteractionStore,
                    onOpenTopicRoute: { route in
                        tabState.appendProfileRoute(route)
                    }
                )
            case .topicComposer(let seedTopicID):
                TopicPostComposerScreen(seedTopicID: seedTopicID, store: topicStore)
            }
        }
    }

    private func quickEntryRoute(for item: ProfileQuickEntryItem) -> ProfileRoute? {
        ProfileQuickEntryRouteResolver.route(for: item)
    }

    private func openPosts() {
        tabState.appendProfileRoute(.posts)
    }
}
