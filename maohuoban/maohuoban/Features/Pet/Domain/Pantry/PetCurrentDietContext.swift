import Foundation

// PetCurrentDietContext 宠物当前饮食上下文
// 核心职责：
// - 对齐后端 diet-context 强事实读模型
// - 为快捷喂食默认食品提供当前主粮引用
struct PetCurrentDietContext: Decodable, Equatable {
    let currentStaple: PetDietContextItem?
    let tryingFoods: [PetDietContextItem]
    let usualTreats: [PetDietContextItem]
    let usualNutritions: [PetDietContextItem]
    let recentFeedingEvents: [PetRecentFeedingFact]

    enum CodingKeys: String, CodingKey {
        case currentStaple = "current_staple"
        case tryingFoods = "trying_foods"
        case usualTreats = "usual_treats"
        case usualNutritions = "usual_nutritions"
        case recentFeedingEvents = "recent_feeding_events"
    }
}

// PetDietContextItem 宠物饮食配置项
// 核心职责：
// - 表达宠物对食品资产的当前配置
// - 暴露食品资产 ID 供前端匹配储物柜选项
struct PetDietContextItem: Decodable, Equatable {
    let assignmentID: String
    let foodItemID: String
    let foodName: String
    let foodBrand: String?
    let foodCategory: String
    let role: String
    let status: String

    init(
        assignmentID: String = "",
        foodItemID: String,
        foodName: String = "",
        foodBrand: String? = nil,
        foodCategory: String = "",
        role: String = "",
        status: String = ""
    ) {
        self.assignmentID = assignmentID
        self.foodItemID = foodItemID
        self.foodName = foodName
        self.foodBrand = foodBrand
        self.foodCategory = foodCategory
        self.role = role
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case assignmentID = "assignment_id"
        case foodItemID = "food_item_id"
        case foodName = "food_name"
        case foodBrand = "food_brand"
        case foodCategory = "food_category"
        case role
        case status
    }
}

// PetRecentFeedingFact 最近喂食事实
// 核心职责：
// - 解码 Agent 饮食上下文中的近期喂食记录
// - 保留食品资产引用和快照字段
struct PetRecentFeedingFact: Decodable, Equatable {
    let eventID: String
    let occurredAt: String
    let foodItemID: String?
    let foodName: String
    let foodSnapshot: PetFoodSnapshot?

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case occurredAt = "occurred_at"
        case foodItemID = "food_item_id"
        case foodName = "food_name"
        case foodSnapshot = "food_snapshot"
    }
}
