import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedDetailCommentEditorHeader 评论输入头部
// 核心职责：
// - 展示当前登录用户头像和输入标题
// - 承接关闭评论输入动作
struct PetWorldFeedDetailCommentEditorHeader: View {
    let currentUserAvatarAssetName: String
    let titleText: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(currentUserAvatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(
                    width: PetWorldFeedDetailLayout.commentComposerAvatarSize,
                    height: PetWorldFeedDetailLayout.commentComposerAvatarSize
                )
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 1)
                }

            Text(titleText)
                .font(MHBTheme.Typography.headline.weight(.bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Spacer(minLength: MHBTheme.Spacing.s3)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭评论输入")
        }
    }
}
