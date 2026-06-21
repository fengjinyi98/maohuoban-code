import SwiftUI
import MaohuobanDesignSystem

// PetWorldNavigationSearchButton 宠物世界导航搜索按钮
// 核心职责：
// - 在系统导航栏右侧承载搜索入口
// - 使用 Liquid Glass 圆形容器提供独立触控反馈
struct PetWorldNavigationSearchButton<Route: Hashable>: View {
    let route: Route

    var body: some View {
        NavigationLink(value: route) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("搜索")
    }
}
