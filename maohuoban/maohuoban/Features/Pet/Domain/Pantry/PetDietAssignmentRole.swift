import Foundation

// PetDietAssignmentRole 宠物饮食配置角色
// 核心职责：
// - 约束前端可提交的饮食关系角色
// - 与后端 pet_diet_assignments.role 枚举保持一致
enum PetDietAssignmentRole: String, Encodable, Equatable, CaseIterable {
    case trying
    case usualTreat = "usual_treat"
    case usualNutrition = "usual_nutrition"
    case backup
    case notSuitable = "not_suitable"
}
