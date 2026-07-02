import SwiftUI

// MHBRootTabStack 单个 Tab 的导航栈壳
// 核心职责：
// - 封装 NavigationStack 与路径绑定
// - 自动管理 TabBar 显隐（push 页面中隐藏系统 TabBar）
// - 每个 Tab 的 RootScreen 自行在 content 内注册 .navigationDestination
struct MHBRootTabStack<Content: View>: View {
    let tab: MHBAppTab
    let tabState: MHBAppTabState
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack(path: tabState.binding(for: tab)) {
            content()
                .background(MHBInteractivePopGestureRestorer())
        }
        .toolbar(tabState.shouldShowTabBar(for: tab) ? .visible : .hidden, for: .tabBar)
    }
}
