import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedList 宠物世界 Feed 列表
// 核心职责：
// - 承载宠物世界信息流纵向滚动布局
// - 通过顶部内容间距避开自定义导航头部
struct PetWorldFeedList: View {
    let cards: [PetWorldFeedItem]
    let topContentInset: CGFloat

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: MHBTheme.Spacing.s8) {
                ForEach(cards) { card in
                    PetWorldFeedCard(card: card)
                        .accessibilityIdentifier("petWorld.feed.card.\(card.id)")
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, topContentInset)
            .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8)
        }
        .scrollIndicators(.hidden)
    }
}
