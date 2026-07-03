import SwiftUI
import MaohuobanDesignSystem

// ProfileRootScreen 我的 Tab 根视图
// 核心职责：
// - 作为"我的"Tab NavigationStack 的根内容
// - 承载个人信息概览和系统导航栏工具入口
struct ProfileRootScreen: View {
    let topicStore: TopicStore
    let tabState: MHBAppTabState
    let currentUserStore: CurrentUserStore
    let appAppearanceStore: AppAppearanceStore
    let onLogout: () -> Void
    @State var feedInteractionStore: FeedInteractionStore
    @State var settingsDeviceSessionStore = SettingsDeviceSessionStore(
        repository: DefaultSettingsDeviceSessionRepository()
    )
    @State private var profileLoader: CurrentUserProfileLoader?

    init(
        topicStore: TopicStore = TopicStore(),
        tabState: MHBAppTabState = MHBAppTabState(),
        currentUserStore: CurrentUserStore,
        appAppearanceStore: AppAppearanceStore = AppAppearanceStore(),
        onLogout: @escaping () -> Void
    ) {
        self.topicStore = topicStore
        self.tabState = tabState
        self.currentUserStore = currentUserStore
        self.appAppearanceStore = appAppearanceStore
        self.onLogout = onLogout
        _feedInteractionStore = State(
            initialValue: FeedInteractionStore(
                cards: ProfileMockFeed.cards(
                    authorName: currentUserStore.displayName,
                    authorAvatarAssetName: currentUserStore.avatarAssetName
                )
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: MHBTheme.Spacing.s3) {
                ProfileAccountSummarySection(
                    profile: currentUserStore.accountSummary,
                    onOpenUserProfile: openUserProfile,
                    onOpenPosts: openPosts,
                    onOpenFollowing: openFollowing,
                    onOpenFollowers: openFollowers
                )

                ProfileQuickEntriesSection(items: ProfileQuickEntryItem.mockItems) { _ in
                } routeForItem: { item in
                    quickEntryRoute(for: item)
                }

                ProfileFAQBanner {
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
        .task {
            if profileLoader == nil {
                profileLoader = CurrentUserProfileLoader(currentUserStore: currentUserStore)
            }
            await profileLoader?.loadProfile()
        }
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
                Button {
                    tabState.appendProfileRoute(.settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("设置")
                .accessibilityIdentifier("profile.settingsButton")
            }
        }
        .navigationDestination(for: ProfileRoute.self) { route in
            destination(for: route)
        }
    }

    private func quickEntryRoute(for item: ProfileQuickEntryItem) -> ProfileRoute? {
        ProfileQuickEntryRouteResolver.route(for: item)
    }

    private func openUserProfile() {
        tabState.appendProfileRoute(.userProfile)
    }

    private func openPosts() {
        tabState.appendProfileRoute(.posts)
    }

    private func openFollowing() {
        tabState.appendProfileRoute(.following)
    }

    private func openFollowers() {
        tabState.appendProfileRoute(.followers)
    }
}
