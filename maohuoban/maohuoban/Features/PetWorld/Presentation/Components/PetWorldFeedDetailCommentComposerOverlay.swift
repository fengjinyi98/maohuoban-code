import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetWorldFeedDetailCommentComposerOverlay 详情页评论输入浮层
// 核心职责：
// - 承载底部快捷评论入口触发后的输入态
// - 提供遮罩关闭、自动聚焦和发送按钮状态
struct PetWorldFeedDetailCommentComposerOverlay: View {
    @Binding var isPresented: Bool
    @Binding var draftText: String
    let replyTargetName: String?
    let currentUserAvatarAssetName: String
    let onSend: () -> Void
    var onDismiss: () -> Void = {}

    @FocusState private var isEditorFocused: Bool

    var body: some View {
        if isPresented {
            ZStack(alignment: .bottom) {
                Button(action: dismissComposer) {
                    Color.black.opacity(0.24)
                        .ignoresSafeArea()
                }
                .buttonStyle(.plain)

                composerSheet
                    .padding(.horizontal, MHBTheme.Spacing.s3)
                    .padding(.bottom, MHBTheme.Spacing.s2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .task(id: isPresented) {
                guard isPresented else {
                    return
                }

                try? await Task.sleep(for: .milliseconds(80))
                isEditorFocused = true
            }
            .animation(PetWorldFeedDetailLayout.commentComposerAnimation, value: isPresented)
        }
    }

    private var composerSheet: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            Capsule()
                .fill(MHBTheme.ColorToken.labelTertiary.color.opacity(0.3))
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, MHBTheme.Spacing.s2)

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

                Button(action: dismissComposer) {
                    Image(systemName: "xmark")
                        .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .frame(width: 32, height: 32)
                        .background(MHBTheme.ColorToken.background.color, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭评论输入")
            }

            TextField(placeholderText, text: $draftText, axis: .vertical)
                .lineLimit(5...)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.vertical, MHBTheme.Spacing.s3)
                .background(MHBTheme.ColorToken.background.color, in: .rect(cornerRadius: MHBTheme.Radius.medium))
                .focused($isEditorFocused)
                .submitLabel(.send)

            HStack(spacing: MHBTheme.Spacing.s3) {
                Button {
                    // 快速 UI 阶段暂不接入评论图片选择。
                } label: {
                    Label("图片", systemImage: "photo")
                        .font(MHBTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .padding(.horizontal, MHBTheme.Spacing.s3)
                        .frame(height: 36)
                        .background(MHBTheme.ColorToken.background.color, in: .rect(cornerRadius: MHBTheme.Radius.small))
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
            .padding(.bottom, MHBTheme.Spacing.s2)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color, in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.10), radius: 20, y: 8)
    }

    private var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var titleText: String {
        if let replyTargetName {
            return "回复 @\(replyTargetName)"
        }

        return "写评论"
    }

    private var placeholderText: String {
        if let replyTargetName {
            return "回复 @\(replyTargetName)..."
        }

        return "有话想说，快来评论"
    }

    private var sendButtonBackgroundColor: Color {
        canSend
            ? MHBTheme.ColorToken.primary.color
            : MHBTheme.ColorToken.labelTertiary.color.opacity(0.35)
    }

    private func dismissComposer() {
        isEditorFocused = false
        isPresented = false
        onDismiss()
    }

    private func sendComment() {
        guard canSend else {
            return
        }

        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.72)
        onSend()
        dismissComposer()
    }
}
