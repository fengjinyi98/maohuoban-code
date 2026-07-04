import Foundation

// PantryItemDraft 储物柜物品草稿
// 核心职责：
// - 承载添加/编辑物品的表单状态
// - 支持分步填写和验证
struct PantryItemDraft {
    var coverImageURL: String?
    var name: String = ""
    var brand: String = ""
    var specification: String = ""
    var category: PantryCategory = .mainFood
    var initialStock: String = ""
    var expiryInfo: String = ""

    var isValid: Bool {
        !name.isEmpty && !brand.isEmpty
    }
}
