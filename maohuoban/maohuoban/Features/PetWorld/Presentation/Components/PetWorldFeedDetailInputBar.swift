import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetWorldFeedDetailInputBar 详情页底部互动评论栏
// 核心职责：
// - 承载评论输入、点赞、评论和转发入口
// - 使用共享点赞状态并覆盖底部安全区
struct PetWorldFeedDetailInputBar: View {
    let isLiked: Bool
    let likeCount: Int
    let commentCount: Int
    let repostCount: Int
    let bottomSafeArea: CGFloat
    let onToggleLike: () -> Void

    @State private var draftComment = ""
    @State private var isLikeFeedbackActive = false

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            PetWorldFeedDetailCommentField(text: $draftComment)
                .layoutPriority(1)

            Button {
                triggerLikeFeedback()
            } label: {
                PetWorldFeedDetailBottomActionItem(
                    systemImage: isLiked ? "heart.fill" : "heart",
                    value: likeCount,
                    isHighlighted: isLiked,
                    iconScale: isLikeFeedbackActive ? PetWorldFeedDetailLayout.likeFeedbackScale : 1
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isLiked ? "取消点赞" : "点赞")

            PetWorldFeedDetailBottomActionItem(
                systemImage: "bubble.right",
                value: commentCount,
                isHighlighted: false
            )
            .accessibilityLabel("评论")

            PetWorldFeedDetailBottomActionItem(
                systemImage: "arrow.2.squarepath",
                value: repostCount,
                isHighlighted: false
            )
            .accessibilityLabel("转发")
        }
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .padding(.top, PetWorldFeedDetailLayout.inputVerticalPadding)
        .padding(.bottom, bottomSafeArea)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 0))
    }

    private func triggerLikeFeedback() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.82)

        withAnimation(PetWorldFeedDetailLayout.likePressAnimation) {
            isLikeFeedbackActive = true
            onToggleLike()
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(PetWorldFeedDetailLayout.likeReleaseAnimation) {
                isLikeFeedbackActive = false
            }
        }
    }
}

// PetWorldFeedDetailCommentField 详情页底部评论输入
// 核心职责：
// - 提供无发送按钮的评论输入入口
// - 在紧凑底栏中保持文本输入区域稳定
private struct PetWorldFeedDetailCommentField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Image(systemName: "bubble.right")
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            TextField("评论一下", text: $text)
                .font(MHBTheme.Typography.callout)
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, MHBTheme.Spacing.s3)
        .frame(height: PetWorldFeedDetailLayout.inputHeight)
        .background(MHBTheme.ColorToken.separator.color, in: Capsule())
    }
}

// PetWorldFeedDetailBottomActionItem 详情页底部互动项
// 核心职责：
// - 组合底部操作图标和滚动计数
// - 根据点赞状态切换强调色并限制命中尺寸
private struct PetWorldFeedDetailBottomActionItem: View {
    let systemImage: String
    let value: Int
    let isHighlighted: Bool
    var iconScale: CGFloat = 1

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1 + MHBTheme.Spacing.s1 / 2) {
            Image(systemName: systemImage)
                .font(.system(size: MHBTheme.IconSize.small + MHBTheme.Spacing.s1 / 2, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .scaleEffect(iconScale)

            PetWorldRollingCountText(
                value: value,
                textColor: foregroundUIColor
            )
        }
        .frame(minWidth: PetWorldFeedDetailLayout.bottomActionHitSize)
        .frame(height: PetWorldFeedDetailLayout.bottomActionHitSize)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var foregroundColor: Color {
        isHighlighted
            ? MHBTheme.ColorToken.danger.color
            : MHBTheme.ColorToken.labelPrimary.color
    }

    private var foregroundUIColor: UIColor {
        isHighlighted
            ? MHBTheme.ColorToken.danger.uiColor
            : MHBTheme.ColorToken.labelPrimary.uiColor
    }
}
