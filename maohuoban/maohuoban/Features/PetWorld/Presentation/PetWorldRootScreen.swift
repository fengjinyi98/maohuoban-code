import SwiftUI
import MaohuobanDesignSystem

// PetWorldRootScreen 宠物世界 Tab 根视图
// 核心职责：
// - 作为宠物世界 Tab NavigationStack 的根内容
// - 承载基于宠物画像的推荐流
struct PetWorldRootScreen: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)

            Text("宠物世界")
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("基于宠物画像的推荐流")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("宠物世界")
    }
}
