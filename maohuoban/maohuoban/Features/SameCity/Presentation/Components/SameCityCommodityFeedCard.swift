import SwiftUI
import MaohuobanDesignSystem

// SameCityCommodityFeedList 同城商品 Feed 列表
// 核心职责：
// - 按同城 tabs 筛选结果展示商品卡片
// - 复用 FeedInteractionStore 管理点赞状态
struct SameCityCommodityFeedList: View {
    let items: [SameCityCommodityFeedItem]
    let interactionStore: FeedInteractionStore
    let onMoreTap: (SameCityCommodityFeedItem) -> Void

    var body: some View {
        LazyVStack(spacing: SameCityCommodityLayout.cardSpacing) {
            ForEach(items) { item in
                SameCityCommodityFeedCard(
                    item: item,
                    interactionState: interactionStore.interactionState(for: item.feedItem),
                    onToggleLike: {
                        interactionStore.toggleLike(postID: item.feedItem.postID)
                    },
                    onMoreTap: {
                        onMoreTap(item)
                    }
                )
                .accessibilityIdentifier("sameCity.commodity.card.\(item.id)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sameCity.commodity.feedList")
    }
}

// SameCityCommodityFeedCard 同城商品 Feed 卡片
// 核心职责：
// - 使用 Feed 基础组件组装商品卡片头部、媒体和互动区
// - 呈现同城商品正文、健康标签和交易操作栏
private struct SameCityCommodityFeedCard: View {
    let item: SameCityCommodityFeedItem
    let interactionState: FeedInteractionState
    let onToggleLike: () -> Void
    let onMoreTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FeedCardMetrics.contentSectionSpacing) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: SameCityCommodityLayout.contentSpacing) {
                    FeedAuthorRow(
                        title: item.feedItem.authorName,
                        subtitle: "\(item.publishedText) · \(item.locationName)",
                        avatarAssetName: item.feedItem.authorAvatarAssetName,
                        badge: item.identity.feedBadge,
                        reservesTrailingButtonSpace: true
                    )

                    FeedMediaContainer(assetName: item.feedItem.mediaAssetName) {
                        SameCityCommodityMediaBadgeView(badge: item.mediaBadge)
                    }

                    SameCityCommodityCaption(text: item.feedItem.text)

                    SameCityCommodityTagList(tags: item.tags)

                    SameCityCommodityTradeActionBar(
                        info: item.tradeInfo,
                        action: item.tradeAction
                    )
                }

                FeedCardMoreButton(
                    postID: item.feedItem.postID,
                    action: .moreMenu,
                    onTap: onMoreTap
                )
                .padding(.top, FeedCardMetrics.moreButtonTopPadding)
                .zIndex(1)
            }

            FeedCardActions(
                isLiked: interactionState.isLiked,
                likeCount: interactionState.likeCount,
                repostCount: item.feedItem.repostCount,
                commentCount: item.feedItem.commentCount,
                onToggleLike: onToggleLike
            )
        }
        .accessibilityElement(children: .contain)
    }
}

// SameCityCommodityMediaBadgeView 同城图片业务角标
// 核心职责：
// - 在 Feed 媒体容器左上角展示商品类型
// - 区分领养和交易类商品的语义色
private struct SameCityCommodityMediaBadgeView: View {
    let badge: SameCityCommodityMediaBadge

    var body: some View {
        Text(badge.title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, MHBTheme.Spacing.s3)
            .padding(.vertical, MHBTheme.Spacing.s2)
            .background(badge.style.backgroundColor, in: .rect(cornerRadius: MHBTheme.Radius.medium))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

// SameCityCommodityCaption 同城商品正文
// 核心职责：
// - 展示商品卡片的描述正文
// - 保持商品卡片正文的普通水平边距
private struct SameCityCommodityCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .lineSpacing(3)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, MHBTheme.Spacing.s1)
    }
}

// SameCityCommodityTagList 同城商品标签流
// 核心职责：
// - 展示健康、证书和保障类短标签
// - 使用 DesignSystem 标签基础设施并保持窄屏自动换行
private struct SameCityCommodityTagList: View {
    let tags: [SameCityCommodityTag]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 102), spacing: MHBTheme.Spacing.s2)],
            alignment: .leading,
            spacing: MHBTheme.Spacing.s2
        ) {
            ForEach(tags) { tag in
                SameCityCommodityTagChip(tag: tag)
            }
        }
        .padding(.horizontal, MHBTheme.Spacing.s1)
    }
}

// SameCityCommodityTagChip 同城商品标签
// 核心职责：
// - 使用统一标签组件展示图标和标签文本
// - 为网格列提供稳定宽度和左对齐
private struct SameCityCommodityTagChip: View {
    let tag: SameCityCommodityTag

    var body: some View {
        MHBTagView(
            tag.title,
            systemImage: tag.systemImageName,
            style: .neutral,
            size: .small
        )
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// SameCityCommodityTradeActionBar 同城交易操作栏
// 核心职责：
// - 展示价格、保障说明和主要交易动作
// - 保持操作区与社交互动区分层清晰
private struct SameCityCommodityTradeActionBar: View {
    let info: SameCityCommodityTradeInfo
    let action: SameCityCommodityTradeAction

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1 / 2) {
                Text(info.title)
                    .font(.system(size: info.style.titleFontSize, weight: .bold))
                    .foregroundStyle(info.style.titleColor)
                    .lineLimit(1)

                Text(info.subtitle)
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                // 待接入同城商品交易流程。
            } label: {
                Label(action.title, systemImage: action.systemImageName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.cardSolid.color)
                    .lineLimit(1)
                    .padding(.horizontal, MHBTheme.Spacing.s3)
                    .frame(height: SameCityCommodityLayout.tradeButtonHeight)
                    .background(MHBTheme.ColorToken.labelPrimary.color, in: .rect(cornerRadius: MHBTheme.Radius.large))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(action.title)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.vertical, MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.cardSolid.color, in: .rect(cornerRadius: MHBTheme.Radius.extraLarge))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                .strokeBorder(MHBTheme.ColorToken.separatorSoft.color, lineWidth: 1)
        }
    }
}

private extension SameCityCommodityMediaBadge.Style {
    var backgroundColor: Color {
        switch self {
        case .adoption:
            MHBTheme.ColorToken.success.color.opacity(0.86)
        case .trade:
            MHBTheme.ColorToken.labelPrimary.color.opacity(0.78)
        }
    }
}

private extension SameCityCommodityTradeInfo.Style {
    var titleColor: Color {
        switch self {
        case .free:
            MHBTheme.ColorToken.success.color
        case .price:
            MHBTheme.ColorToken.danger.color
        }
    }

    var titleFontSize: CGFloat {
        switch self {
        case .free:
            18
        case .price:
            20
        }
    }
}

// SameCityCommodityLayout 同城商品卡片布局参数
// 核心职责：
// - 收敛商品卡片间距与交易按钮尺寸
// - 避免布局尺寸散落在业务视图中
private enum SameCityCommodityLayout {
    static let cardSpacing: CGFloat = MHBTheme.Spacing.s8 + MHBTheme.Spacing.s2
    static let contentSpacing: CGFloat = MHBTheme.Spacing.s3 + MHBTheme.Spacing.s1 / 2
    static let tradeButtonHeight: CGFloat = MHBTheme.Spacing.s8 + MHBTheme.Spacing.s2
}
