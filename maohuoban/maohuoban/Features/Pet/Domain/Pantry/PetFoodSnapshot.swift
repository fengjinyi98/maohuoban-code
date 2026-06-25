import Foundation

// PetFoodSnapshot 喂食食品快照
// 核心职责：
// - 解码后端喂食事件中的食品快照
// - 允许品牌和规格为空，保障历史喂食记录可展示
struct PetFoodSnapshot: Decodable, Equatable {
    let name: String
    let brand: String?
    let category: String
    let spec: String?

    subscript(key: String) -> String? {
        switch key {
        case "name":
            name
        case "brand":
            brand
        case "category":
            category
        case "spec":
            spec
        default:
            nil
        }
    }
}
