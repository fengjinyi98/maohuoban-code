import SwiftUI
import MaohuobanDesignSystem
import UIKit

// FeedCard 通用 UGC Feed 卡片
// 核心职责：
// - 呈现头像、作者、场景文案、媒体内容和互动数据
// - 为宠物世界、我的动态等内容流提供一致卡片展示
struct FeedCard<DetailRoute: Hashable>: View {
    let card: FeedItem
    let interactionState: FeedInteractionState
    let detailRoute: DetailRoute
    let topTrailingAction: FeedCardTopTrailingAction
    let showsRecommendationReason: Bool
    let onToggleLike: () -> Void
    let onMoreTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FeedCardMetrics.contentSectionSpacing) {
            NavigationLink(value: detailRoute) {
                VStack(alignment: .leading, spacing: FeedCardMetrics.contentSectionSpacing) {
                    FeedCardHeader(
                        title: card.petName ?? card.authorName,
                        recommendationReason: card.recommendationReason,
                        showsRecommendationReason: showsRecommendationReason,
                        authorName: card.authorName,
                        publishedAt: card.publishedAt,
                        avatarAssetName: card.petAvatarAssetName ?? card.authorAvatarAssetName
                    )

                    FeedCardText(text: card.text)

                    FeedCardMedia(assetName: card.mediaAssetName)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("查看动态详情")

            FeedCardActions(
                isLiked: interactionState.isLiked,
                likeCount: interactionState.likeCount,
                repostCount: card.repostCount,
                commentCount: card.commentCount,
                onToggleLike: onToggleLike
            )
        }
        .accessibilityElement(children: .contain)
        .overlay(alignment: .topTrailing) {
            FeedCardMoreButton(
                postID: card.postID,
                action: topTrailingAction,
                onTap: onMoreTap
            )
            .padding(.top, FeedCardMetrics.moreButtonTopPadding)
            .zIndex(1)
        }
    }
}

// FeedCardText Feed 卡片正文
// 核心职责：
// - 展示图片上方的卡片正文内容
// - 将正文起点对齐到媒体圆角后的直线区域
private struct FeedCardText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, FeedCardMetrics.mediaTextLeadingInset)
            .padding(.trailing, MHBTheme.Spacing.s2)
    }
}

// FeedCardHeader Feed 卡片头部
// 核心职责：
// - 展示宠物头像、宠物名称和发帖人时间信息
// - 承载自定义更多菜单的触发入口和锚点测量
private struct FeedCardHeader: View {
    let title: String
    let recommendationReason: FeedRecommendationReason
    let showsRecommendationReason: Bool
    let authorName: String
    let publishedAt: Date
    let avatarAssetName: String

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            Image(avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: FeedCardMetrics.avatarSize, height: FeedCardMetrics.avatarSize)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1 / 2) {
                HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)
                        .layoutPriority(1)

                    if showsRecommendationReason {
                        FeedRecommendationBadge(reason: recommendationReason)
                    }
                }

                Text("by \(authorName) · \(publishedAt, format: MHBUTCDateDisplayFormatter.localShortDateTimeStyle())")
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: MHBTheme.Spacing.s2)

            Color.clear
                .frame(
                    width: FeedCardMetrics.moreButtonHitSize,
                    height: FeedCardMetrics.moreButtonHitSize
                )
                .allowsHitTesting(false)
        }
    }
}

// FeedCardMoreButton Feed 卡片更多按钮
// 核心职责：
// - 在卡片顶层提供稳定的更多操作命中区域
// - 向列表层上报按钮 frame 作为自定义菜单锚点
private struct FeedCardMoreButton: View {
    let postID: String
    let action: FeedCardTopTrailingAction
    let onTap: () -> Void

    var body: some View {
        Image(systemName: action.systemImageName)
            .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
            .foregroundStyle(action.foregroundColor)
            .frame(width: MHBTheme.Spacing.s8, height: MHBTheme.Spacing.s8)
            .frame(
                width: FeedCardMetrics.moreButtonHitSize,
                height: FeedCardMetrics.moreButtonHitSize,
                alignment: .trailing
            )
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded {
                    onTap()
                }
            )
        .feedMoreButtonFrame(postID: postID)
        .accessibilityLabel(action.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onTap()
        }
    }
}

// FeedRecommendationBadge Feed 推荐解释标签
// 核心职责：
// - 在宠物名称后展示推荐关系短标签
// - 使用与发帖人时间信息一致的轻量文本样式
private struct FeedRecommendationBadge: View {
    let reason: FeedRecommendationReason

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1) {
            Image(systemName: "exclamationmark.circle.fill")
                .imageScale(.small)

            Text(reason.text)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(MHBTheme.Typography.footnote)
        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
    }
}

// FeedCardMedia Feed 卡片媒体图
// 核心职责：
// - 展示参考 HTML 风格的大圆角图片
// - 使用轻量内描边增强图片边界
private struct FeedCardMedia: View {
    let assetName: String

    var body: some View {
        GeometryReader { proxy in
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .aspectRatio(FeedCardMetrics.mediaAspectRatio, contentMode: .fit)
        .background(MHBTheme.ColorToken.separatorSoft.color)
        .clipShape(FeedCardMetrics.mediaShape)
        .overlay {
            FeedCardMetrics.mediaShape
                .strokeBorder(
                    MHBTheme.ColorToken.labelPrimary.color.opacity(FeedCardMetrics.mediaInnerBorderOpacity),
                    lineWidth: FeedCardMetrics.mediaInnerBorderWidth
                )
        }
    }
}

// FeedCardActions Feed 卡片互动区
// 核心职责：
// - 展示点赞、转发、评论和分享入口
// - 保持参考 HTML 的轻量低对比图标文本组合
private struct FeedCardActions: View {
    let isLiked: Bool
    let likeCount: Int
    let repostCount: Int
    let commentCount: Int
    let onToggleLike: () -> Void

    @State private var isLikeFeedbackActive = false

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: FeedCardMetrics.actionItemSpacing) {
                Button {
                    triggerLikeFeedback()
                } label: {
                    FeedActionItem(
                        systemImage: isLiked ? "heart.fill" : "heart",
                        value: likeCount,
                        isHighlighted: isLiked,
                        iconScale: isLikeFeedbackActive ? FeedCardMetrics.likeFeedbackScale : 1
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isLiked ? "取消点赞" : "点赞")

                FeedActionItem(
                    systemImage: "arrow.2.squarepath",
                    value: repostCount,
                    isHighlighted: false
                )

                FeedActionItem(
                    systemImage: "bubble.right",
                    value: commentCount,
                    isHighlighted: false
                )
            }

            Spacer()

            Button {
                // 待接入卡片分享。
            } label: {
                Image(systemName: "paperplane")
                    .font(.system(size: MHBTheme.IconSize.small + MHBTheme.Spacing.s1 / 2, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(width: MHBTheme.Spacing.s8, height: MHBTheme.Spacing.s8)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("分享")
        }
        .padding(.horizontal, MHBTheme.Spacing.s2)
        .padding(.top, MHBTheme.Spacing.s1)
    }

    private func triggerLikeFeedback() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.82)

        withAnimation(FeedCardMetrics.likePressAnimation) {
            isLikeFeedbackActive = true
            onToggleLike()
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(FeedCardMetrics.likeReleaseAnimation) {
                isLikeFeedbackActive = false
            }
        }
    }
}

// FeedActionItem Feed 卡片互动数据项
// 核心职责：
// - 组合互动图标和计数文本
// - 根据强调状态切换语义色
private struct FeedActionItem: View {
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
        .accessibilityElement(children: .combine)
    }

    private var foregroundColor: Color {
        isHighlighted
            ? MHBTheme.ColorToken.danger.color
            : MHBTheme.ColorToken.labelSecondary.color
    }

    private var foregroundUIColor: UIColor {
        isHighlighted
            ? MHBTheme.ColorToken.danger.uiColor
            : MHBTheme.ColorToken.labelSecondary.uiColor
    }
}

// FeedCardMetrics Feed 卡片视觉参数
// 核心职责：
// - 收敛参考 HTML 转译后的卡片局部尺寸
// - 让卡片主视图保持渲染职责清晰
private enum FeedCardMetrics {
    static let avatarSize: CGFloat = MHBTheme.Spacing.s8 + MHBTheme.Spacing.s5
    static let contentSectionSpacing: CGFloat = (MHBTheme.Spacing.s3 + MHBTheme.Spacing.s1 / 2) / 2
    static let mediaAspectRatio: CGFloat = 1.04
    static let mediaCornerRadius: CGFloat = MHBTheme.Radius.extraExtraLarge + MHBTheme.Spacing.s5 - MHBTheme.Spacing.s1 / 2
    static let mediaInnerBorderWidth: CGFloat = MHBTheme.Spacing.s1
    static let mediaInnerBorderOpacity = 0.14
    static let mediaTextLeadingInset: CGFloat = mediaCornerRadius
    static let actionItemSpacing: CGFloat = MHBTheme.Spacing.s6 - MHBTheme.Spacing.s1 / 2
    static let moreButtonHitSize: CGFloat = 44
    static let moreButtonTopPadding: CGFloat = (avatarSize - moreButtonHitSize) / 2
    static let likeFeedbackScale: CGFloat = 1.18
    static let likePressAnimation = Animation.smooth(duration: 0.08, extraBounce: 0)
    static let likeReleaseAnimation = Animation.interactiveSpring(
        response: 0.28,
        dampingFraction: 0.56,
        blendDuration: 0.08
    )

    static var mediaShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: mediaCornerRadius, style: .continuous)
    }
}
