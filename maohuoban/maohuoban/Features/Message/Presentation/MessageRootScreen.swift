import SwiftUI
import MaohuobanDesignSystem

// MessageRootScreen 消息 Tab 根视图
// 核心职责：
// - 作为消息 Tab NavigationStack 的根内容
// - 承载私信/评论/交易沟通/系统通知列表
struct MessageRootScreen: View {
    let tabState: MHBAppTabState

    init(tabState: MHBAppTabState = MHBAppTabState()) {
        self.tabState = tabState
    }

    var body: some View {
        MHBTabPlaceholderRootScreen(
            systemImage: "bubble.fill",
            title: "消息",
            subtitle: "通信与通知中心",
            accessibilityIdentifier: "message.root"
        )
        .safeAreaInset(edge: .bottom) {
            MessageTabsExperimentEntryButton {
                tabState.appendMessageRoute(.tabsExperiment)
            }
        }
        .navigationDestination(for: MessageRoute.self) { route in
            MessageRouteDestinationScreen(route: route)
        }
    }
}

// MessageTabsExperimentEntryButton 消息 tabs 实验入口
// 核心职责：
// - 在消息占位页提供显式实验入口
// - 将点击事件转发给消息 Tab 路由路径
private struct MessageTabsExperimentEntryButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("打开 Tabs 实验", systemImage: "rectangle.3.group.bubble.left")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, MHBTheme.Spacing.s5)
                .frame(height: 48)
                .background(MHBTheme.ColorToken.primary.color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, MHBTheme.Spacing.s3)
        .padding(.bottom, MHBTheme.Spacing.s3)
        .accessibilityIdentifier("message.tabsExperiment.entry")
    }
}
