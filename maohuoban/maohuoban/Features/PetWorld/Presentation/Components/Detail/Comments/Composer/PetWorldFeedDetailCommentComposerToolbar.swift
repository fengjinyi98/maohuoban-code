import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetWorldFeedDetailCommentComposerToolbar 评论输入键盘工具条
// 核心职责：
// - 承载评论图片入口和发送动作
// - 作为评论输入面板内部的底部操作区
struct PetWorldFeedDetailCommentComposerToolbar: View {
    let draftText: String
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Button {
                // 快速 UI 阶段暂不接入评论图片选择。
            } label: {
                Label("图片", systemImage: "photo")
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
