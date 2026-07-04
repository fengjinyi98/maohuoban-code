import Foundation

// PetPantryEmptyStatePresentation 储物柜空态展示模型
// 核心职责：
// - 固定用户级储物柜空态文案
// - 避免空态退回到宠物饮食配置语义
nonisolated struct PetPantryEmptyStatePresentation: Equatable {
    let title: String
    let message: String
    let buttonTitle: String

    static let `default` = PetPantryEmptyStatePresentation(
        title: "还没有常备物品",
        message: "添加猫粮、零食、营养品或清洁用品后，家庭储物柜会按分类整理它们。",
        buttonTitle: "添加第一个物品"
    )
}
