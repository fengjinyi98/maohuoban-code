import SwiftUI

// HomeRouteDestinationScreen 首页路由目标占位页
// 核心职责：
// - 为首页动作提供真实系统导航目标
// - 后续让对应业务模块替换具体页面实现
struct HomeRouteDestinationScreen: View {
    let route: HomeRoute

    var body: some View {
        MHBTabPlaceholderRootScreen(
            systemImage: route.systemImage,
            title: route.title,
            subtitle: route.subtitle,
            accessibilityIdentifier: "home.routeDestination"
        )
    }
}
