import SwiftUI
import MaohuobanDesignSystem

// PantryItemFeedingTimelineSection 物品喂食时间线区
// 核心职责：
// - 展示当前物品相关的喂食事件
// - 布局参考首页时间线的纵向记录样式
struct PantryItemFeedingTimelineSection: View {
    let entries: [FoodInventoryFeedingTimelineEntry]
    let onOpenEntry: (FoodInventoryFeedingTimelineEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            Text("喂食时间线")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            if entries.isEmpty {
                Text("暂无喂食记录")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        PantryItemFeedingTimelineRow(
                            entry: entry,
                            isFirst: index == 0,
                            isLast: index == entries.count - 1,
                            onOpen: {
                                onOpenEntry(entry)
                            }
                        )
                    }
                }
            }
        }
    }
}
