import SwiftUI
import MaohuobanDesignSystem

// MHBAppShell 应用主壳
// 核心职责：
// - 组装 5 个底部 Tab 的 TabView
// - 将 router 的 tabState 分发给各 Tab 的导航栈
// - 提供退出登录入口传给"我的"Tab
struct MHBAppShell: View {
    @Bindable var router: MHBAppRouter
    @Bindable var currentUserStore: CurrentUserStore
    let appAppearanceStore: AppAppearanceStore
    let onLogout: () -> Void
    @State private var topicStore = TopicStore()
    @State private var homeQuickFactContext = HomeActionRoutingContext()
    @State private var homeQuickFactRefreshToken = 0

    private var shouldShowHomeQuickFactAccessory: Bool {
        router.selectedTab == .home &&
        router.tabState.shouldShowTabBar(for: .home) &&
        homeQuickFactContext.selectedPetID != nil
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            MHBRootTabStack(tab: .home, tabState: router.tabState, isSelected: router.selectedTab == .home) {
                HomeRootScreen(
                    currentUserStore: currentUserStore,
                    tabState: router.tabState,
                    quickFactRefreshToken: homeQuickFactRefreshToken,
                    onQuickFactContextChanged: { context in
                        homeQuickFactContext = context
                    }
                )
            }

            MHBRootTabStack(tab: .petWorld, tabState: router.tabState, isSelected: router.selectedTab == .petWorld) {
                PetWorldRootScreen(
                    topicStore: topicStore,
                    tabState: router.tabState,
                    currentUserStore: currentUserStore
                )
            }
            .preferredColorScheme(MHBAppTab.petWorld.appliesAppAppearancePreference ? appAppearanceStore.preferredColorScheme : nil)

            MHBRootTabStack(tab: .sameCity, tabState: router.tabState, isSelected: router.selectedTab == .sameCity) {
                SameCityRootScreen(
                    topicStore: topicStore,
                    tabState: router.tabState,
                    currentUserStore: currentUserStore
                )
            }
            .preferredColorScheme(MHBAppTab.sameCity.appliesAppAppearancePreference ? appAppearanceStore.preferredColorScheme : nil)

            MHBRootTabStack(tab: .message, tabState: router.tabState, isSelected: router.selectedTab == .message) {
                MessageRootScreen()
            }
            .preferredColorScheme(MHBAppTab.message.appliesAppAppearancePreference ? appAppearanceStore.preferredColorScheme : nil)

            MHBRootTabStack(tab: .profile, tabState: router.tabState, isSelected: router.selectedTab == .profile) {
                ProfileRootScreen(
                    topicStore: topicStore,
                    tabState: router.tabState,
                    currentUserStore: currentUserStore,
                    appAppearanceStore: appAppearanceStore,
                    onLogout: onLogout
                )
            }
            .preferredColorScheme(MHBAppTab.profile.appliesAppAppearancePreference ? appAppearanceStore.preferredColorScheme : nil)
        }
        .tabViewBottomAccessory(isEnabled: shouldShowHomeQuickFactAccessory) {
            HomeQuickFactActionBar(
                routingContext: homeQuickFactContext,
                currentUserID: currentUserStore.userID,
                onOpenRoute: { route in
                    router.tabState.appendHomeRoute(route)
                },
                onRecorded: {
                    homeQuickFactRefreshToken += 1
                }
            )
        }
        .tint(MHBTheme.ColorToken.primary.color)
    }
}
