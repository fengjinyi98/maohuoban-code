import SwiftUI

// PantryItemDetailPhaseView 物品详情状态视图
// 核心职责：
// - 根据详情加载阶段展示加载、错误和内容
// - 保持主屏只负责状态分发
struct PantryItemDetailPhaseView: View {
    let phase: PetFoodInventoryItemDetailStore.Phase
    let onOpenFeedingRecord: (FoodInventoryFeedingTimelineEntry) -> Void

    var body: some View {
        switch phase {
        case .idle, .loading:
            PantryItemDetailLoadingView()
        case .failed(let message):
            PantryItemDetailErrorView(message: message)
        case .deleted:
            PantryItemDetailErrorView(message: "物品已移出储物柜")
        case .loaded(let detail):
            PantryItemDetailContentView(
                detail: detail,
                onOpenFeedingRecord: onOpenFeedingRecord
            )
        }
    }
}
