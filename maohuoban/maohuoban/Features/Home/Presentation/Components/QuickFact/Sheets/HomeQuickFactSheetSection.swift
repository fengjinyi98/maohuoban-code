import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactSheetSection 快捷事实弹层分组
// 核心职责：
// - 统一 sheet 内标题和内容间距
// - 提供轻量表单分组结构
struct HomeQuickFactSheetSection<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            content()
        }
    }
}
