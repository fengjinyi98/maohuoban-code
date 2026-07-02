import SwiftUI
import MaohuobanDesignSystem

// SameCityCommodityGrowthRecordCardView 商品成长记录入口卡片
// 核心职责：
// - 展示导入宠物记录后的成长记录摘要入口
// - 复刻设计稿中标题、统计和缩略图聚合入口的核心视觉
struct SameCityCommodityGrowthRecordCardView: View {
    let card: SameCityCommodityGrowthRecordCard
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                SameCityCommodityGrowthRecordHeader(card: card)

                SameCityCommodityGrowthRecordThumbnailStrip(card: card)
            }
            .padding(MHBTheme.Spacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                MHBTheme.ColorToken.background.color,
                in: .rect(cornerRadius: MHBTheme.Radius.large)
            )
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
            }
            .contentShape(.rect(cornerRadius: MHBTheme.Radius.large))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.title)，\(card.summaryText)")
    }
}

// SameCityCommodityGrowthRecordHeader 成长记录卡片头部
// 核心职责：
// - 展示成长记录标题和图文动态数量
// - 保持右侧进入提示的紧凑布局
private struct SameCityCommodityGrowthRecordHeader: View {
    let card: SameCityCommodityGrowthRecordCard

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s2) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)

                Text(card.title)
                    .font(MHBTheme.Typography.callout.weight(.bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .layoutPriority(1)

            Spacer(minLength: MHBTheme.Spacing.s2)

            HStack(spacing: MHBTheme.Spacing.s1) {
                Text(card.summaryText)
                    .font(MHBTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
        }
    }
}

// SameCityCommodityGrowthRecordThumbnailStrip 成长记录缩略图条
// 核心职责：
// - 展示导入记录的前置图片预览
// - 使用剩余数量方块提示还有更多图文动态
private struct SameCityCommodityGrowthRecordThumbnailStrip: View {
    let card: SameCityCommodityGrowthRecordCard

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            ForEach(card.thumbnailAssetNames, id: \.self) { assetName in
                SameCityCommodityGrowthRecordThumbnail(assetName: assetName)
            }

            if card.remainingThumbnailCount > 0 {
                SameCityCommodityGrowthRecordRemainingBadge(count: card.remainingThumbnailCount)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// SameCityCommodityGrowthRecordThumbnail 成长记录单张缩略图
// 核心职责：
// - 使用固定尺寸承载记录图片
// - 保持缩略图圆角和描边一致
private struct SameCityCommodityGrowthRecordThumbnail: View {
    let assetName: String

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(
                width: SameCityCommodityGrowthRecordCardLayout.thumbnailSize,
                height: SameCityCommodityGrowthRecordCardLayout.thumbnailSize
            )
            .clipShape(.rect(cornerRadius: MHBTheme.Radius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                    .strokeBorder(MHBTheme.ColorToken.separatorSoft.color, lineWidth: 1)
            }
    }
}

// SameCityCommodityGrowthRecordRemainingBadge 成长记录剩余数量提示
// 核心职责：
// - 展示未露出的图文动态数量
// - 与缩略图保持同尺寸网格占位
private struct SameCityCommodityGrowthRecordRemainingBadge: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(MHBTheme.Typography.footnote.weight(.bold))
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .frame(
                width: SameCityCommodityGrowthRecordCardLayout.thumbnailSize,
                height: SameCityCommodityGrowthRecordCardLayout.thumbnailSize
            )
            .background(
                MHBTheme.ColorToken.separatorSoft.color,
                in: .rect(cornerRadius: MHBTheme.Radius.medium)
            )
    }
}

// SameCityCommodityGrowthRecordCardLayout 成长记录卡片布局参数
// 核心职责：
// - 收敛缩略图固定尺寸
// - 保持卡片内部元素布局稳定
private enum SameCityCommodityGrowthRecordCardLayout {
    static let thumbnailSize: CGFloat = 56
}
