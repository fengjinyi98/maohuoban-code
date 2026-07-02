import SwiftUI
import MaohuobanDesignSystem

// SameCityCommodityDetailContent 同城商品详情正文
// 核心职责：
// - 按设计稿 section 组织商品价格、资料、故事、要求和发布者信息
// - 在正文底部复用 Feed 详情元信息、话题和留言树组件
struct SameCityCommodityDetailContent: View {
    let detail: SameCityCommodityDetailItem
    let comments: [FeedComment]
    let topPadding: CGFloat
    let topicRoute: (String) -> SameCityRoute
    let onOpenTopicRoute: (SameCityRoute) -> Void
    let onGrowthRecordTap: () -> Void
    let onPublisherOffsetChange: (CGFloat) -> Void
    let onCommentReply: (FeedComment) -> Void
    let onCommentToggleLike: (FeedComment) -> Void
    let onCommentLongPress: (FeedComment) -> Void

    var body: some View {
        let separatorPolicy = SameCityCommodityDetailContentSeparatorPolicy.resolve(
            hasGrowthRecordCard: detail.growthRecordCard != nil
        )

        VStack(alignment: .leading, spacing: SameCityCommodityDetailLayout.sectionSpacing) {
            SameCityCommodityDetailTitleSection(
                tradeTitle: detail.tradeTitle,
                tradeSubtitle: detail.tradeSubtitle,
                title: detail.title,
                metaTags: detail.metaTags
            )

            if separatorPolicy.showsDividerAfterTitle {
                SameCityCommodityDetailDivider()
            }

            if let growthRecordCard = detail.growthRecordCard {
                SameCityCommodityGrowthRecordCardView(
                    card: growthRecordCard,
                    onTap: onGrowthRecordTap
                )

                if separatorPolicy.showsDividerAfterGrowthRecordCard {
                    SameCityCommodityDetailDivider()
                }
            }

            SameCityCommodityHealthSection(items: detail.healthItems)

            SameCityCommodityDetailDivider()

            SameCityCommodityStorySection(
                title: detail.storyTitle,
                paragraphs: detail.storyParagraphs
            )

            SameCityCommodityDetailDivider()

            SameCityCommodityRequirementSection(
                title: detail.requirementTitle,
                requirements: detail.requirements
            )

            SameCityCommodityDetailDivider()

            SameCityCommodityDetailBottomMetadataSection(
                visibleLocationName: detail.visibleLocationName,
                viewCount: detail.viewCount,
                topics: detail.topics,
                topicRoute: topicRoute,
                onOpenTopicRoute: onOpenTopicRoute
            )

            SameCityCommodityPublisherSection(
                publisher: detail.publisher,
                onOffsetChange: onPublisherOffsetChange
            )

            FeedDetailCommentsSection(
                title: "留言",
                comments: comments,
                onReply: onCommentReply,
                onToggleLike: onCommentToggleLike,
                onLongPress: onCommentLongPress
            )
        }
        .padding(.horizontal, SameCityCommodityDetailLayout.contentHorizontalPadding)
        .padding(.top, topPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
