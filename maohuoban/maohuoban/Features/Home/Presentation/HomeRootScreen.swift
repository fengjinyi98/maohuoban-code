import SwiftUI
import MaohuobanDesignSystem

// HomeRootScreen 首页 Tab 根视图
// 核心职责：
// - 作为首页 Tab NavigationStack 的根内容
// - 后续在此注册 HomeRoute 的 navigationDestination
struct HomeRootScreen: View {
    var body: some View {
        MHBTabPlaceholderRootScreen(
            systemImage: "house.fill",
            title: "首页",
            subtitle: "宠物工作台 · 当前宠物主卡",
            accessibilityIdentifier: "home.root"
        )
    }
}
