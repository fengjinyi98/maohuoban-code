import SwiftUI
import MaohuobanDesignSystem

// ProfileUserHomeScreen 用户个人主页
// 核心职责：
// - 组合个人主页沉浸式头图、资料区和内容区
// - 通过 ProfileRoute 承接我的 Tab 内部系统导航
struct ProfileUserHomeScreen: View {
    let profile: ProfileUserHome
    let onOpenRoute: (ProfileRoute) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedTabID: String

    init(
        profile: ProfileUserHome = .mock,
        onOpenRoute: @escaping (ProfileRoute) -> Void = { _ in }
    ) {
        self.profile = profile
        self.onOpenRoute = onOpenRoute
        _selectedTabID = State(initialValue: profile.tabContents.first?.id ?? "")
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ProfileUserHomeCoverSection(
                            assetName: profile.coverAssetName,
                            scrollOffset: scrollOffset
                        )

                        ProfileUserHomeIdentitySection(
                            displayName: profile.displayName,
                            petID: profile.petID,
                            bio: profile.bio,
                            avatarSubject: profile.avatarSubject,
                            genderSystemImage: profile.genderSystemImage,
                            editRoute: ProfileRoute.editUserProfile
                        )

                        ProfileUserHomeStatsSection(stats: profile.stats)

                        ProfileUserHomePetFamilySection(pets: profile.pets)

                        ProfileUserHomeTabsBar(
                            tabs: profile.tabContents,
                            selectedTabID: $selectedTabID
                        )

                        ProfileUserHomePostGrid(
                            posts: selectedTabContent.posts,
                            onOpenPost: openPost
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .coordinateSpace(name: "profileUserHomeScrollView")
                .ignoresSafeArea(edges: .top)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, offset in
                    scrollOffset = max(offset, 0)
                }

                ProfileUserHomeNavigationChrome(
                    title: profile.displayName,
                    avatarSubject: profile.avatarSubject,
                    progress: navigationProgress,
                    aiRoute: ProfileRoute.aiAssistant(profile.aiEntryContext),
                    onBack: {
                        dismiss()
                    },
                    onShare: {
                    }
                )
                .padding(.top, MHBTheme.Spacing.s1)
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .zIndex(1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .accessibilityIdentifier("profile.userHome.screen")
    }

    private var selectedTabContent: ProfileUserHomeTabContent {
        profile.tabContents.first(where: { $0.id == selectedTabID })
            ?? profile.tabContents.first
            ?? ProfileUserHomeTabContent(id: "empty", title: "动态", countText: nil, posts: [])
    }

    private var navigationProgress: CGFloat {
        ProfileUserHomeLayout.navigationProgress(for: scrollOffset)
    }

    private func openPost(_ post: ProfileUserHomePost) {
        guard let detailPostID = post.detailPostID else {
            return
        }

        onOpenRoute(.feedDetail(postID: detailPostID))
    }
}

// ProfileUserHomeLayout 用户个人主页布局参数
// 核心职责：
// - 收敛头图、导航和滚动阈值
// - 让各 section 使用同一套几何基准
enum ProfileUserHomeLayout {
    nonisolated static let coverHeight: CGFloat = 280
    nonisolated static let navigationTransitionStartOffset: CGFloat = 150
    nonisolated static let navigationTransitionEndOffset: CGFloat = 210
    nonisolated static let heroFullBlurStartOffset: CGFloat = 40
    nonisolated static let heroFullBlurEndOffset: CGFloat = 160
    nonisolated static let heroDefaultScale: CGFloat = 1.08
    nonisolated static let heroShrinkSpeedMultiplier: CGFloat = 8

    nonisolated static func navigationProgress(for scrollOffset: CGFloat) -> CGFloat {
        let range = max(navigationTransitionEndOffset - navigationTransitionStartOffset, 1)
        let rawProgress = (scrollOffset - navigationTransitionStartOffset) / range
        return min(max(rawProgress, 0), 1)
    }
}
