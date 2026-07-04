import SwiftUI
import MaohuobanDesignSystem

// PantryItemDetailContentView 物品详情内容
// 核心职责：
// - 组合基础信息、消耗统计、关联宠物和喂食时间线
// - 仅渲染后端详情读模型
struct PantryItemDetailContentView: View {
    let detail: FoodInventoryItemDetail
    let isMutating: Bool
    let onOpenFeedingRecord: (FoodInventoryFeedingTimelineEntry) -> Void
    let onConsumeOne: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
            PantryItemDetailHeader(item: detail.item)
            PantryItemConsumptionSummarySection(summary: detail.consumptionSummary)
            PantryItemLinkedPetsSection(linkedPets: detail.linkedPets)
            PantryItemFeedingTimelineSection(
                entries: detail.feedingTimeline,
                onOpenEntry: onOpenFeedingRecord
            )
            PantryItemConsumeCTASection(
                item: detail.item,
                isSubmitting: isMutating,
                onConsumeOne: onConsumeOne
            )
        }
    }
}
