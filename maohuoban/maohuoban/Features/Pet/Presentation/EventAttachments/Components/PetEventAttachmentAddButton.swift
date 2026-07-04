import SwiftUI
import MaohuobanDesignSystem

// PetEventAttachmentAddButton 事件附件添加按钮
// 核心职责：
// - 以小尺寸虚线框承载照片添加入口
// - 保持与相册新建卡片一致的添加视觉语义
struct PetEventAttachmentAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: MHBTheme.Spacing.s1) {
                Image(systemName: "plus")
                    .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))

                Text("添加")
                    .font(MHBTheme.Typography.caption.weight(.semibold))
            }
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .frame(width: 76, height: 76)
            .background(MHBTheme.ColorToken.background.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                    .stroke(
                        MHBTheme.ColorToken.labelQuaternary.color,
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 5])
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("添加照片")
    }
}
