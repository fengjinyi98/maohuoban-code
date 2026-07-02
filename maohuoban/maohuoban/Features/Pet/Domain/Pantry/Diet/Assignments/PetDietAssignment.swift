import Foundation

// PetDietAssignment 宠物饮食配置关系
// 核心职责：
// - 对齐后端 pet_diet_assignments 响应
// - 为储物柜食品资产建立宠物饮食角色关系
struct PetDietAssignment: Decodable, Equatable, Identifiable {
    let id: String
    let petID: String
    let foodItemID: String
    let role: String
    let status: String
    let startedAt: String?
    let endedAt: String?
    let reason: String?
    let createdByUserID: String?
    let createdAt: String?
    let updatedAt: String?

    init(
        id: String,
        petID: String,
        foodItemID: String,
        role: String,
        status: String,
        startedAt: String? = nil,
        endedAt: String? = nil,
        reason: String? = nil,
        createdByUserID: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.petID = petID
        self.foodItemID = foodItemID
        self.role = role
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.reason = reason
        self.createdByUserID = createdByUserID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case petID = "pet_id"
        case foodItemID = "food_item_id"
        case role
        case status
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case reason
        case createdByUserID = "created_by_user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
