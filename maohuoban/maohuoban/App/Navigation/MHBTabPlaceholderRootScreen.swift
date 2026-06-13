import SwiftUI
import MaohuobanDesignSystem

// MHBTabPlaceholderRootScreen Tab 根占位视图
// 核心职责：
// - 统一各业务 Tab 未完成阶段的占位页面结构
// - 使用 DesignSystem token 管理图标、文字、背景样式
struct MHBTabPlaceholderRootScreen: View {
    let systemImage: String
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let accessibilityIdentifier: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: systemImage)
                .font(.system(size: MHBTheme.IconSize.tabRootPlaceholder))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)

            Text(title)
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text(subtitle)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle(Text(title))
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
