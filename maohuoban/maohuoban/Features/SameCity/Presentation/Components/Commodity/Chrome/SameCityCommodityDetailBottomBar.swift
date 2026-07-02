import SwiftUI
import UIKit
import MaohuobanDesignSystem

// SameCityCommodityDetailBottomBar 同城商品详情底部操作栏
// 核心职责：
// - 复用帖子详情页底部 Liquid Glass 容器
// - 承载收藏、点赞和私聊沟通三个操作入口
struct SameCityCommodityDetailBottomBar: View {
    let isFavorite: Bool
    let isLiked: Bool
    let bottomSafeArea: CGFloat
    let onToggleFavorite: () -> Void
    let onToggleLike: () -> Void
    let onPrivateChat: () -> Void

    @State private var isFavoriteFeedbackActive = false
    @State private var isLikeFeedbackActive = false

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Button {
                triggerFavoriteFeedback()
            } label: {
                SameCityCommodityDetailBottomIconAction(
                    title: "收藏",
                    systemImage: isFavorite ? "bookmark.fill" : "bookmark",
                    isHighlighted: isFavorite,
                    iconScale: isFavoriteFeedbackActive ? FeedDetailLayout.likeFeedbackScale : 1
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "取消收藏" : "收藏")

            Button {
                triggerLikeFeedback()
            } label: {
                SameCityCommodityDetailBottomIconAction(
                    title: "点赞",
                    systemImage: isLiked ? "heart.fill" : "heart",
                    isHighlighted: isLiked,
                    iconScale: isLikeFeedbackActive ? FeedDetailLayout.likeFeedbackScale : 1
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isLiked ? "取消点赞" : "点赞")

            Button(action: onPrivateChat) {
                Label("私聊沟通", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(MHBTheme.Typography.callout.weight(.bold))
                    .foregroundStyle(MHBTheme.ColorToken.cardSolid.color)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: SameCityCommodityDetailLayout.bottomPrimaryButtonHeight)
                    .background(MHBTheme.ColorToken.labelPrimary.color, in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("私聊沟通")
        }
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .padding(.top, SameCityCommodityDetailLayout.bottomBarTopPadding)
        .padding(.bottom, bottomSafeArea)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 0))
    }

    private func triggerFavoriteFeedback() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.72)

        withAnimation(FeedDetailLayout.likePressAnimation) {
            isFavoriteFeedbackActive = true
            onToggleFavorite()
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(FeedDetailLayout.likeReleaseAnimation) {
                isFavoriteFeedbackActive = false
            }
        }
    }

    private func triggerLikeFeedback() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.82)

        withAnimation(FeedDetailLayout.likePressAnimation) {
            isLikeFeedbackActive = true
            onToggleLike()
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(FeedDetailLayout.likeReleaseAnimation) {
                isLikeFeedbackActive = false
            }
        }
    }
}

// SameCityCommodityDetailBottomIconAction 商品详情底部图标操作
// 核心职责：
// - 展示底部收藏和点赞的图标文字组合
// - 根据选中态切换强调色和点击反馈缩放
private struct SameCityCommodityDetailBottomIconAction: View {
    let title: String
    let systemImage: String
    let isHighlighted: Bool
    let iconScale: CGFloat

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s1) {
            Image(systemName: systemImage)
                .font(.system(size: MHBTheme.IconSize.small + 2, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .scaleEffect(iconScale)

            Text(title)
                .font(MHBTheme.Typography.section)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineLimit(1)
        }
        .frame(width: 48, height: SameCityCommodityDetailLayout.bottomPrimaryButtonHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var foregroundColor: Color {
        isHighlighted
            ? MHBTheme.ColorToken.danger.color
            : MHBTheme.ColorToken.labelPrimary.color
    }
}
