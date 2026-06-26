import SwiftUI
import MaohuobanDesignSystem
import UIKit

// AIAssistantAttachmentSelectionChip 附件来源选择提示
// 核心职责：
// - 展示用户刚选择的媒体来源
// - 提供清除当前选择的显式按钮
struct AIAssistantAttachmentSelectionChip: View {
    let title: String
    let image: UIImage?
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))
            } else {
                Image(systemName: "photo.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
            }

            Text(title)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("清除附件来源")
        }
        .padding(.horizontal, MHBTheme.Spacing.s2)
        .frame(height: 24)
        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
        .clipShape(Capsule())
    }
}
