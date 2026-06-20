import SwiftUI
import MaohuobanDesignSystem

// MHBAppShell 应用主壳
// 核心职责：
// - 组装 5 个底部 Tab 的 TabView
// - 将 router 的 tabState 分发给各 Tab 的导航栈
// - 提供退出登录入口传给"我的"Tab
struct MHBAppShell: View {
    @Bindable var router: MHBAppRouter
    let currentUserID: String?
    let onLogout: () -> Void
    @State private var topicStore = TopicStore()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            MHBRootTabStack(tab: .home, tabState: router.tabState, isSelected: router.selectedTab == .home) {
                HomeRootScreen(
                    currentUserID: currentUserID,
                    onOpenProfile: {
                        router.switchToTab(.profile)
                    }
                )
            }

            MHBRootTabStack(tab: .petWorld, tabState: router.tabState, isSelected: router.selectedTab == .petWorld) {
                PetWorldRootScreen(topicStore: topicStore, tabState: router.tabState)
            }

            MHBRootTabStack(tab: .sameCity, tabState: router.tabState, isSelected: router.selectedTab == .sameCity) {
                SameCityRootScreen()
            }

            MHBRootTabStack(tab: .message, tabState: router.tabState, isSelected: router.selectedTab == .message) {
                MessageRootScreen()
            }

            MHBRootTabStack(tab: .profile, tabState: router.tabState, isSelected: router.selectedTab == .profile) {
                ProfileRootScreen(
                    topicStore: topicStore,
                    tabState: router.tabState,
                    currentUserID: currentUserID,
                    onLogout: onLogout
                )
            }
        }
        .tint(MHBTheme.ColorToken.primary.color)
    }
}
