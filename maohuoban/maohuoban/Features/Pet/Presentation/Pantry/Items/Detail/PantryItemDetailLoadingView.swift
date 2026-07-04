import SwiftUI
import MaohuobanDesignSystem

// PantryItemDetailLoadingView 物品详情加载态
// 核心职责：
// - 在详情读模型加载期间提供反馈
struct PantryItemDetailLoadingView: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            ProgressView()
            Text("正在加载物品详情")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }
}
