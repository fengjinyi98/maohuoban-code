import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedCard 宠物世界 Feed 卡片
// 核心职责：
// - 呈现头像、作者、场景文案、媒体内容和互动数据
// - 复刻参考 HTML 的大圆角图片、轻内描边和低对比操作区
struct PetWorldFeedCard: View {
    let card: PetWorldFeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3 + MHBTheme.Spacing.s1 / 2) {
            PetWorldFeedCardHeader(
                title: card.petName ?? card.authorName,
                authorName: card.authorName,
                publishedAt: card.publishedAt,
                avatarAssetName: card.petAvatarAssetName ?? card.authorAvatarAssetName
            )

            Text(card.text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            PetWorldFeedCardMedia(assetName: card.mediaAssetName)

            PetWorldFeedCardActions(
                isLiked: card.isLiked,
                likeCount: card.likeCount,
                repostCount: card.repostCount,
                commentCount: card.commentCount
            )
        }
        .accessibilityElement(children: .contain)
    }
}

// PetWorldFeedCardHeader Feed 卡片头部
// 核心职责：
// - 展示宠物头像、宠物名称和发帖人时间信息
// - 承载更多操作入口的视觉占位
private struct PetWorldFeedCardHeader: View {
    let title: String
    let authorName: String
    let publishedAt: Date
    let avatarAssetName: String

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            Image(avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: PetWorldFeedCardMetrics.avatarSize, height: PetWorldFeedCardMetrics.avatarSize)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1 / 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)

                Text("by \(authorName) · \(publishedAt, format: MHBUTCDateDisplayFormatter.localShortDateTimeStyle())")
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: MHBTheme.Spacing.s2)

            Button {
                // 待接入卡片更多操作。
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(width: MHBTheme.Spacing.s8, height: MHBTheme.Spacing.s8)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("更多")
        }
    }
}

// PetWorldFeedCardMedia Feed 卡片媒体图
// 核心职责：
// - 展示参考 HTML 风格的大圆角图片
// - 使用轻量内描边增强图片边界
private struct PetWorldFeedCardMedia: View {
    let assetName: String

    var body: some View {
        GeometryReader { proxy in
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .aspectRatio(PetWorldFeedCardMetrics.mediaAspectRatio, contentMode: .fit)
        .background(MHBTheme.ColorToken.separatorSoft.color)
        .clipShape(PetWorldFeedCardMetrics.mediaShape)
        .overlay {
            PetWorldFeedCardMetrics.mediaShape
                .strokeBorder(
                    MHBTheme.ColorToken.labelPrimary.color.opacity(0.06),
                    lineWidth: PetWorldFeedCardMetrics.mediaInnerBorderWidth
                )
        }
    }
}

// PetWorldFeedCardActions Feed 卡片互动区
// 核心职责：
// - 展示点赞、转发、评论和分享入口
// - 保持参考 HTML 的轻量低对比图标文本组合
private struct PetWorldFeedCardActions: View {
    let isLiked: Bool
    let likeCount: Int
    let repostCount: Int
    let commentCount: Int

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: PetWorldFeedCardMetrics.actionItemSpacing) {
                PetWorldFeedActionItem(
                    systemImage: isLiked ? "heart.fill" : "heart",
                    value: likeCount,
                    isHighlighted: isLiked
                )

                PetWorldFeedActionItem(
                    systemImage: "arrow.2.squarepath",
                    value: repostCount,
                    isHighlighted: false
                )

                PetWorldFeedActionItem(
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
}

// PetWorldFeedActionItem Feed 卡片互动数据项
// 核心职责：
// - 组合互动图标和计数文本
// - 根据强调状态切换语义色
private struct PetWorldFeedActionItem: View {
    let systemImage: String
    let value: Int
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1 + MHBTheme.Spacing.s1 / 2) {
            Image(systemName: systemImage)
                .font(.system(size: MHBTheme.IconSize.small + MHBTheme.Spacing.s1 / 2, weight: .semibold))

            Text("\(value)")
                .font(.system(size: 14, weight: .medium))
                .monospacedDigit()
        }
        .foregroundStyle(foregroundColor)
        .accessibilityElement(children: .combine)
    }

    private var foregroundColor: Color {
        isHighlighted
            ? MHBTheme.ColorToken.danger.color
            : MHBTheme.ColorToken.labelSecondary.color
    }
}

// PetWorldFeedCardMetrics Feed 卡片视觉参数
// 核心职责：
// - 收敛参考 HTML 转译后的卡片局部尺寸
// - 让卡片主视图保持渲染职责清晰
private enum PetWorldFeedCardMetrics {
    static let avatarSize: CGFloat = MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6
    static let mediaAspectRatio: CGFloat = 1.04
    static let mediaCornerRadius: CGFloat = MHBTheme.Radius.extraExtraLarge + MHBTheme.Spacing.s5 - MHBTheme.Spacing.s1 / 2
    static let mediaInnerBorderWidth: CGFloat = MHBTheme.Spacing.s3 / 2
    static let actionItemSpacing: CGFloat = MHBTheme.Spacing.s6 - MHBTheme.Spacing.s1 / 2

    static var mediaShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: mediaCornerRadius, style: .continuous)
    }
}
