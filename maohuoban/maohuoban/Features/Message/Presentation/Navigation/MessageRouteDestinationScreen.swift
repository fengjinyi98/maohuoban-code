import SwiftUI

// MessageRouteDestinationScreen 消息路由目标页
// 核心职责：
// - 将消息 Tab 路由映射到对应实验页面
// - 保持消息模块内部 push 入口集中声明
struct MessageRouteDestinationScreen: View {
    let route: MessageRoute

    var body: some View {
        switch route {
        case .tabsExperiment:
            MessageTabsExperimentScreen()
        }
    }
}
