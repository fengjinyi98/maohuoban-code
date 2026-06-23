import SwiftUI
import MaohuobanDesignSystem

// ProfileUserHomeScreen 用户个人主页
// 核心职责：
// - 组合个人主页沉浸式头图、资料区和内容区
// - 通过 ProfileRoute 承接我的 Tab 内部系统导航
struct ProfileUserHomeScreen: View {
    @Bindable var currentUserStore: CurrentUserStore
    let content: ProfileUserHome
    let onOpenRoute: (ProfileRoute) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedTabID: String

    init(
        currentUserStore: CurrentUserStore,
        content: ProfileUserHome = .mock,
        onOpenRoute: @escaping (ProfileRoute) -> Void = { _ in }
    ) {
        self.currentUserStore = currentUserStore
        self.content = content
        self.onOpenRoute = onOpenRoute
        _selectedTabID = State(initialValue: content.tabContents.first?.id ?? "")
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ProfileUserHomeCoverSection(
                            assetName: content.coverAssetName,
                            coverURLString: currentUserStore.coverURLString,
                            scrollOffset: scrollOffset
                        )

                        ProfileUserHomeIdentitySection(
                            displayName: displayNameValue,
                            maohuobanID: currentUserStore.maohuobanID,
                            ipLocation: content.ipLocation,
                            bio: currentUserStore.bio,
                            avatarSubject: currentUserStore.avatarSubject,
                            professionalBadge: content.professionalBadge,
                            editRoute: ProfileRoute.editUserProfile
                        )

                        ProfileUserHomeStatsSection(stats: content.stats)

                        ProfileUserHomePetFamilySection(pets: content.pets)

                        ProfileUserHomeTabsBar(
                            tabs: content.tabContents,
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
                    title: displayNameValue,
                    avatarSubject: currentUserStore.avatarSubject,
                    progress: navigationProgress,
                    aiRoute: ProfileRoute.aiAssistant(aiEntryContext),
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
        content.tabContents.first(where: { $0.id == selectedTabID })
            ?? content.tabContents.first
            ?? ProfileUserHomeTabContent(id: "empty", title: "动态", countText: nil, posts: [])
    }

    private var displayNameValue: String {
        currentUserStore.displayName
    }

    private var aiEntryContext: AIAssistantEntryContext {
        AIAssistantEntryContext(
            selectedPetID: content.pets.first?.id,
            selectedPetName: content.pets.first?.name,
            selectedPetSpecies: .cat,
            ugcContextTitle: "\(displayNameValue) 的个人主页"
        )
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
