import SwiftUI
import MaohuobanDesignSystem

// FeedDetailCommentsEmptyState Feed 详情评论空状态
// 核心职责：
// - 为帖子详情和商品详情提供统一的空评论展示
// - 使用设计稿文案引导用户留下第一条互动
struct FeedDetailCommentsEmptyState: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            Image("FeedCommentEmptyIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(MHBTheme.ColorToken.labelQuaternary.color)
                .frame(width: 96, height: 96)

            VStack(spacing: MHBTheme.Spacing.s2) {
                Text("还没有人留言")
                    .font(MHBTheme.Typography.headline.weight(.bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text("抢沙发！快来给可爱的毛孩子留个言，分享你的看法吧。")
                    .font(MHBTheme.Typography.footnote.weight(.medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 300)
        }
        .padding(.horizontal, MHBTheme.Spacing.s6)
        .padding(.top, MHBTheme.Spacing.s3)
        .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s2)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("feed.detail.comments.empty")
    }
}
