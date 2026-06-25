import Foundation

// PantryCategory 储物柜分类
// 核心职责：
// - 约束物品分类枚举
// - 支持筛选栏展示
enum PantryCategory: String, Decodable, Equatable, CaseIterable {
    case all = "all"
    case mainFood = "main_food"
    case wetFood = "wet_food"
    case treats = "treats"
    case supplements = "supplements"
    case other = "other"
    case catLitter = "cat_litter"
    case medicine = "medicine"

    var displayName: String {
        switch self {
        case .all: "全部"
        case .mainFood: "主食干粮"
        case .wetFood: "湿粮/罐头"
        case .treats: "零食奖励"
        case .supplements: "营养保健"
        case .other: "其他"
        case .catLitter: "猫砂"
        case .medicine: "药品"
        }
    }
}
