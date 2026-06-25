import Foundation

// PetFoodAssignmentRequest 饮食配置请求
// 核心职责：
// - 编码尝试中、常用零食/营养品、备用和不适合等关系
// - 记录用户设置原因便于后端审计
struct PetFoodAssignmentRequest: Encodable {
    let food_item_id: String
    let role: PetDietAssignmentRole
    let reason: String?
}
