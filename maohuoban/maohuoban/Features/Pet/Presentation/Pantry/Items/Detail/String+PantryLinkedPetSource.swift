import Foundation

// String+PantryLinkedPetSource 关联宠物来源展示
// 核心职责：
// - 将后端关联来源映射为详情页文案
extension String {
    var pantryLinkedPetSourceText: String {
        switch self {
        case "feeding_event":
            "来自喂食记录"
        case "diet_assignment":
            "来自饮食配置"
        default:
            "来自饮食数据"
        }
    }
}
