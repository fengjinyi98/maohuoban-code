import Foundation

// FoodInventoryCategory+PantryDetailDisplay 物品详情分类展示
// 核心职责：
// - 将后端食品分类映射为详情页展示文案
extension FoodInventoryCategory {
    var pantryDetailDisplayText: String {
        switch self {
        case .mainFood: "主粮"
        case .wetFood: "罐头/湿粮"
        case .treats: "零食"
        case .nutrition: "营养品"
        case .other: "其他"
        case .catLitter: "猫砂"
        case .medicine: "药品"
        }
    }
}
