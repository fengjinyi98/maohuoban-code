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
    let currentUserAvatarSubject: MHBAvatarSubject
    let onCommentTap: () -> Void
    let onToggleLike: () -> Void

    @State private var isLikeFeedbackActive = false

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            PetWorldFeedDetailCommentEntryButton(
                currentUserAvatarSubject: currentUserAvatarSubject,
                action: onCommentTap
            )
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

            Button(action: onCommentTap) {
                PetWorldFeedDetailBottomActionItem(
                    systemImage: "bubble.right",
                    value: commentCount,
                    isHighlighted: false
                )
            }
            .buttonStyle(.plain)
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

// PetWorldFeedDetailCommentEntryButton 详情页底部评论入口
// 核心职责：
// - 展示当前登录用户头像和评论占位文案
// - 点击后交给屏幕级评论输入浮层处理
private struct PetWorldFeedDetailCommentEntryButton: View {
    let currentUserAvatarSubject: MHBAvatarSubject
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                MHBAvatar(
                    subject: currentUserAvatarSubject,
                    size: .custom(PetWorldFeedDetailLayout.inputAvatarSize),
                    shape: .circle
                )

                Text("评论一下")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, MHBTheme.Spacing.s1)
            .padding(.trailing, MHBTheme.Spacing.s3)
            .frame(height: PetWorldFeedDetailLayout.inputHeight)
            .background(MHBTheme.ColorToken.separator.color, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("写评论")
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

            FeedRollingCountText(
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
