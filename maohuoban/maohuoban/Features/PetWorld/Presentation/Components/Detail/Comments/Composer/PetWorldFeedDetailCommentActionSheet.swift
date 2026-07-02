import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedDetailCommentActionSheet 评论操作面板
// 核心职责：
// - 承接评论长按后的底部操作
// - 根据评论所有权展示删除或举报危险操作
struct PetWorldFeedDetailCommentActionSheet: View {
    let comment: FeedComment
    let onReply: () -> Void
    let onCopy: () -> Void
    let onReport: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s5) {
            Capsule()
                .fill(MHBTheme.ColorToken.labelTertiary.color.opacity(0.28))
                .frame(width: 44, height: 5)
                .padding(.top, MHBTheme.Spacing.s2)

            VStack(spacing: 0) {
                actionRow(
                    title: "回复",
                    systemImage: "bubble.left",
                    foregroundColor: MHBTheme.ColorToken.labelPrimary.color,
                    action: onReply
                )

                Divider().padding(.leading, 60)

                actionRow(
                    title: "复制",
                    systemImage: "doc.on.doc",
                    foregroundColor: MHBTheme.ColorToken.labelPrimary.color,
                    action: onCopy
                )
            }
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(.rect(cornerRadius: MHBTheme.Radius.extraExtraLarge))

            VStack(spacing: 0) {
                actionRow(
                    title: comment.isOwnedByCurrentUser ? "删除" : "举报",
                    systemImage: comment.isOwnedByCurrentUser ? "trash" : "exclamationmark.triangle",
                    foregroundColor: MHBTheme.ColorToken.danger.color,
                    action: comment.isOwnedByCurrentUser ? onDelete : onReport
                )
            }
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(.rect(cornerRadius: MHBTheme.Radius.extraExtraLarge))
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.bottom, MHBTheme.Spacing.s3)
    }

    private func actionRow(
        title: String,
        systemImage: String,
        foregroundColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s4) {
                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .regular))
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(MHBTheme.Typography.body)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
        }
        .buttonStyle(PetWorldFeedDetailCommentActionSheetRowButtonStyle())
    }
}

// PetWorldFeedDetailCommentActionSheetOverlay 评论操作遮罩
// 核心职责：
// - 提供底部评论操作面板的呈现和退出动画
// - 通过遮罩点击关闭当前操作上下文
struct PetWorldFeedDetailCommentActionSheetOverlay: View {
    let comment: FeedComment
    let onDismiss: () -> Void
    let onReply: () -> Void
    let onCopy: () -> Void
    let onReport: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Button(action: onDismiss) {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
            }
            .buttonStyle(.plain)

            PetWorldFeedDetailCommentActionSheet(
                comment: comment,
                onReply: onReply,
                onCopy: onCopy,
                onReport: onReport,
                onDelete: onDelete
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(PetWorldFeedDetailLayout.commentComposerAnimation, value: comment.id)
    }
}

// PetWorldFeedDetailCommentActionSheetRowButtonStyle 评论操作行按钮样式
// 核心职责：
// - 为操作面板的整行按钮提供按压反馈
// - 保证点击命中范围覆盖整行
private struct PetWorldFeedDetailCommentActionSheetRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.rect)
            .background(
                MHBTheme.ColorToken.primary.color.opacity(configuration.isPressed ? 0.08 : 0)
            )
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
