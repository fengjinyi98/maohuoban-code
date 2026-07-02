import SwiftUI
import MaohuobanDesignSystem

// SameCityLocalFeedSection 同城动态区块
// 核心职责：
// - 在 Feed 流前展示同城动态标题
// - 保持现有同城商品 Feed 列表组件不变
struct SameCityLocalFeedSection: View {
    let items: [SameCityCommodityFeedItem]
    let interactionStore: FeedInteractionStore
    let detailRoute: (SameCityCommodityFeedItem) -> SameCityRoute
    let onMoreTap: (SameCityCommodityFeedItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            SameCityLocalFeedTitle()

            if items.isEmpty {
                SameCityEmptyFeedSurface()
            } else {
                SameCityCommodityFeedList(
                    items: items,
                    interactionStore: interactionStore,
                    detailRoute: detailRoute,
                    onMoreTap: onMoreTap
                )
            }
        }
    }
}

// SameCityLocalFeedTitle 同城动态标题
// 核心职责：
// - 标识下方内容为同城动态 Feed
// - 与页面标题层级保持区分
struct SameCityLocalFeedTitle: View {
    var body: some View {
        Text("同城动态")
            .font(MHBTheme.Typography.headline.weight(.bold))
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("sameCity.feed.title")
    }
}

// SameCityEmptyFeedSurface 同城空 feed 承载面
// 核心职责：
// - 为暂无商品的分类提供稳定占位
// - 提供可滚动内容面以配合底部发布按钮边界
struct SameCityEmptyFeedSurface: View {
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(minHeight: SameCityRootLayout.emptyFeedMinHeight)
            .accessibilityHidden(true)
    }
}
