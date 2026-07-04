import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactActionButtonContent 快捷事实按钮内容
// 核心职责：
// - 统一渲染点击与长按按钮的原始稳定样式
// - 保持按钮本体不承载长按确认特效
struct HomeQuickFactActionButtonContent: View {
    let action: HomeQuickFactAction
    let isSubmitting: Bool
    let isRecorded: Bool

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s1) {
            iconContent

            Text(action.title)
                .font(MHBTheme.Typography.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(foregroundColor)
        .frame(width: 58, height: 48)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var iconContent: some View {
        if isSubmitting {
            ProgressView()
                .controlSize(.mini)
                .tint(foregroundColor)
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: isRecorded ? "checkmark" : action.systemImage)
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .frame(width: 18, height: 18)
        }
    }

    private var foregroundColor: Color {
        if isRecorded {
            return MHBTheme.ColorToken.primary.color
        }
        return action == .abnormal ? MHBTheme.ColorToken.warning.color : MHBTheme.ColorToken.labelPrimary.color
    }
}
