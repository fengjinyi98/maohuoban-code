import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactFeedingPantryList 喂食储物柜物品列表
// 核心职责：
// - 展示当前展开分类下的储物柜物品
// - 让用户在同一分类内切换具体喂食内容
struct HomeQuickFactFeedingPantryList: View {
    let kind: HomeQuickFactFeedingFoodKind
    let selectedItemID: String?
    let foodOptions: [HomeQuickFactFeedingFoodOption]
    let onSelectItem: (HomeQuickFactFeedingFoodOption) -> Void

    private var items: [HomeQuickFactFeedingFoodOption] {
        HomeQuickFactFeedingFoodSource.items(for: kind, in: foodOptions)
    }

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            if items.isEmpty {
                HomeQuickFactFeedingManualItemRow(kind: kind)
            } else {
                ForEach(items) { item in
                    HomeQuickFactFeedingPantryItemRow(
                        item: item,
                        isSelected: selectedItemID == item.id,
                        action: {
                            onSelectItem(item)
                        }
                    )
                }
            }
        }
        .padding(.leading, MHBTheme.Spacing.s4)
    }
}
