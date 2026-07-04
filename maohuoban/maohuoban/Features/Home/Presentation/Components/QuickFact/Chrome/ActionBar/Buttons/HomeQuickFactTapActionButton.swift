import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactTapActionButton 快捷事实点击按钮
// 核心职责：
// - 承载喂食和异常等普通点击动作
// - 保持与长按按钮一致的尺寸和反馈状态
struct HomeQuickFactTapActionButton: View {
    let action: HomeQuickFactAction
    let isSubmitting: Bool
    let isRecorded: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HomeQuickFactActionButtonContent(
                action: action,
                isSubmitting: isSubmitting,
                isRecorded: isRecorded
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled && !isSubmitting)
        .accessibilityLabel(Text(action.title))
        .accessibilityValue(isRecorded ? Text("已记录") : Text(""))
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }
}
