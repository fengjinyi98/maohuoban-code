import Foundation

// FoodInventoryStatus+PantryDetailDisplay 物品详情状态展示
// 核心职责：
// - 将后端库存状态映射为详情页展示文案
extension FoodInventoryStatus {
    var pantryDetailDisplayText: String {
        switch self {
        case .active: "可用"
        case .sealed: "未拆封"
        case .inUse: "喂食中"
        case .depleted: "已耗尽"
        case .archived: "已移出"
        }
    }
}
