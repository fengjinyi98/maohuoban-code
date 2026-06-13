import SwiftUI
import MaohuobanDesignSystem

// SameCityRootScreen 同城 Tab 根视图
// 核心职责：
// - 作为同城 Tab NavigationStack 的根内容
// - 承载本地服务入口（医院/猫舍/宠物店）
struct SameCityRootScreen: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "map.fill")
                .font(.system(size: 48))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)

            Text("同城")
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("本地服务 · 医院 / 猫舍 / 宠物店")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("同城")
    }
}
