import SwiftUI
import MaohuobanDesignSystem

// HomeRootScreen 首页 Tab 根视图
// 核心职责：
// - 作为首页 Tab NavigationStack 的根内容
// - 后续在此注册 HomeRoute 的 navigationDestination
struct HomeRootScreen: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "house.fill")
                .font(.system(size: 48))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)

            Text("首页")
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("宠物工作台 · 当前宠物主卡")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("首页")
    }
}
