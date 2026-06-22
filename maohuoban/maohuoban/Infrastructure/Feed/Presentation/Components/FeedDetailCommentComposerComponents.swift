import SwiftUI
import UIKit
import MaohuobanDesignSystem

// FeedDetailCommentInputShield Feed 详情评论输入遮罩
// 核心职责：
// - 在键盘评论输入出现时拦截页面上方空白区域点击
// - 避免触发底层图片预览和页面点击手势
struct FeedDetailCommentInputShield: View {
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("关闭输入")
    }
}

// FeedDetailCommentEditorHeader Feed 详情评论输入头部
// 核心职责：
// - 展示当前登录用户头像和输入标题
// - 承接关闭评论或留言输入动作
struct FeedDetailCommentEditorHeader: View {
    let currentUserAvatarAssetName: String
    let titleText: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(currentUserAvatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(
                    width: FeedDetailLayout.commentComposerAvatarSize,
                    height: FeedDetailLayout.commentComposerAvatarSize
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
            .accessibilityLabel("关闭输入")
        }
    }
}

// FeedDetailCommentComposerToolbar Feed 详情评论输入工具条
// 核心职责：
// - 承载图片入口和发送动作
// - 根据草稿内容控制发送按钮可用状态
struct FeedDetailCommentComposerToolbar: View {
    let draftText: String
    let imageButtonTitle: String
    let onSend: () -> Void

    init(
        draftText: String,
        imageButtonTitle: String = "图片",
        onSend: @escaping () -> Void
    ) {
        self.draftText = draftText
        self.imageButtonTitle = imageButtonTitle
        self.onSend = onSend
    }

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Button {
                // 快速 UI 阶段暂不接入图片选择。
            } label: {
                Label(imageButtonTitle, systemImage: "photo")
                    .font(MHBTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .padding(.horizontal, MHBTheme.Spacing.s3)
                    .frame(height: 36)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)

            Spacer(minLength: MHBTheme.Spacing.s3)

            Button(action: sendComment) {
                Text("发送")
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .frame(height: 36)
                    .background(sendButtonBackgroundColor, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
    }

    private var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sendButtonBackgroundColor: Color {
        canSend
            ? MHBTheme.ColorToken.primary.color
            : MHBTheme.ColorToken.labelTertiary.color.opacity(0.35)
    }

    private func sendComment() {
        guard canSend else {
            return
        }

        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.72)
        onSend()
    }
}
