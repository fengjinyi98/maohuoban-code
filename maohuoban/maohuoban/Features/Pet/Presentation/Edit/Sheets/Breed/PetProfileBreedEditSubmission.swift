import Foundation

// PetProfileBreedEditSubmission 宠物品种编辑提交值
// 核心职责：
// - 统一品种输入保存前的空白规范化
// - 为添加和编辑档案复用同一份提交规则
struct PetProfileBreedEditSubmission: Equatable {
    let value: String

    init(rawValue: String) {
        value = rawValue.filter { !$0.isWhitespace }
    }
}
