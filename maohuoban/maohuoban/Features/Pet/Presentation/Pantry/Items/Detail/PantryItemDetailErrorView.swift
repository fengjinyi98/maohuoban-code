import SwiftUI
import MaohuobanDesignSystem

// PantryItemDetailErrorView 物品详情错误态
// 核心职责：
// - 展示详情加载失败原因
struct PantryItemDetailErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.warning.color)
            Text(message)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }
}
