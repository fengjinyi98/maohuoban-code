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
    @State private var activeHomeQuickFactSheet: HomeQuickFactSheet?
    @State private var homeQuickFactSheetStore = PetWriteStore()
    @State private var homeQuickFactSheetSubmittingAction: HomeQuickFactAction?

    private var shouldShowHomeQuickFactAccessory: Bool {
        router.selectedTab == .home &&
        router.tabState.shouldShowTabBar(for: .home) &&
        homeQuickFactContext.selectedPetID != nil
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab(value: MHBAppTab.home) {
                MHBRootTabStack(tab: .home, tabState: router.tabState) {
                    HomeRootScreen(
                        currentUserStore: currentUserStore,
                        tabState: router.tabState,
                        quickFactRefreshToken: homeQuickFactRefreshToken,
                        onQuickFactContextChanged: { context in
                            homeQuickFactContext = context
                        }
                    )
                }
            } label: {
                tabLabel(for: .home)
            }

            Tab(value: MHBAppTab.petWorld) {
                MHBRootTabStack(tab: .petWorld, tabState: router.tabState) {
                    PetWorldRootScreen(
                        topicStore: topicStore,
                        tabState: router.tabState,
                        currentUserStore: currentUserStore
                    )
                }
                .preferredColorScheme(MHBAppTab.petWorld.appliesAppAppearancePreference ? appAppearanceStore.preferredColorScheme : nil)
            } label: {
                tabLabel(for: .petWorld)
            }
            .tabPlacement(.sidebarOnly)

            Tab(value: MHBAppTab.sameCity) {
                MHBRootTabStack(tab: .sameCity, tabState: router.tabState) {
                    SameCityRootScreen(
                        topicStore: topicStore,
                        tabState: router.tabState,
                        currentUserStore: currentUserStore
                    )
                }
                .preferredColorScheme(MHBAppTab.sameCity.appliesAppAppearancePreference ? appAppearanceStore.preferredColorScheme : nil)
            } label: {
                tabLabel(for: .sameCity)
            }
            .tabPlacement(.sidebarOnly)

            Tab(value: MHBAppTab.message) {
                MHBRootTabStack(tab: .message, tabState: router.tabState) {
                    MessageRootScreen()
                }
                .preferredColorScheme(MHBAppTab.message.appliesAppAppearancePreference ? appAppearanceStore.preferredColorScheme : nil)
            } label: {
                tabLabel(for: .message)
            }
            .tabPlacement(.sidebarOnly)

            Tab(value: MHBAppTab.profile) {
                MHBRootTabStack(tab: .profile, tabState: router.tabState) {
                    ProfileRootScreen(
                        topicStore: topicStore,
                        tabState: router.tabState,
                        currentUserStore: currentUserStore,
                        appAppearanceStore: appAppearanceStore,
                        onLogout: onLogout
                    )
                }
                .preferredColorScheme(MHBAppTab.profile.appliesAppAppearancePreference ? appAppearanceStore.preferredColorScheme : nil)
            } label: {
                tabLabel(for: .profile)
            }
        }
        .tabViewBottomAccessory(isEnabled: shouldShowHomeQuickFactAccessory) {
            HomeQuickFactActionBar(
                routingContext: homeQuickFactContext,
                currentUserID: currentUserStore.userID,
                onOpenRoute: { route in
                    router.tabState.appendHomeRoute(route)
                },
                onOpenSheet: openQuickFactSheet,
                onRecorded: {
                    homeQuickFactRefreshToken += 1
                }
            )
        }
        .defaultTabBarPlacement(.tabBar)
        .tabBarMinimizeBehavior(.never)
        .tint(MHBTheme.ColorToken.primary.color)
        .petWriteToastBridge(
            phase: homeQuickFactSheetStore.phase,
            successMessage: homeQuickFactSheetStore.successMessage
        )
        .sheet(item: $activeHomeQuickFactSheet) { sheet in
            switch sheet {
            case .feeding:
                HomeQuickFactFeedingSheet(
                    context: homeQuickFactContext,
                    isSubmitting: homeQuickFactSheetSubmittingAction == .fed,
                    onSubmit: submitQuickFactFeeding,
                    onCancel: {
                        activeHomeQuickFactSheet = nil
                    }
                )
            }
        }
    }

    private func openQuickFactSheet(_ sheet: HomeQuickFactSheet) {
        homeQuickFactSheetStore.reset()
        homeQuickFactSheetSubmittingAction = nil
        activeHomeQuickFactSheet = sheet
    }

    private func submitQuickFactFeeding(_ input: HomeQuickFactFeedingInput) {
        submitQuickFactSheetEvent(
            action: .fed,
            petID: input.petID,
            draft: input.eventDraft()
        )
    }

    private func submitQuickFactSheetEvent(
        action: HomeQuickFactAction,
        petID: String?,
        draft: PetEventDraft
    ) {
        guard homeQuickFactSheetSubmittingAction == nil else { return }

        homeQuickFactSheetSubmittingAction = action
        Task {
            await homeQuickFactSheetStore.createEvent(
                petID: petID,
                draft: draft,
                currentUserID: currentUserStore.userID
            )

            homeQuickFactSheetSubmittingAction = nil

            if case .recordedEvent = homeQuickFactSheetStore.phase {
                activeHomeQuickFactSheet = nil
                homeQuickFactRefreshToken += 1
            }
        }
    }

    private func tabLabel(for tab: MHBAppTab) -> some View {
        Label {
            Text(tab.title)
        } icon: {
            Image(systemName: tab.systemImage(isSelected: router.selectedTab == tab))
        }
    }
}
