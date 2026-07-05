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
    var initialStatus: PantryItemInitialStatus = .sealed
    var initialStock: String = ""
    var expiryInfo: String = ""

    var isValid: Bool {
        !name.isEmpty && !brand.isEmpty
    }
}

// PantryItemInitialStatus 物品初始状态
// 核心职责：
// - 区分全新未拆封和已开封消耗中
enum PantryItemInitialStatus: String, CaseIterable {
    case sealed = "sealed"
    case inUse = "in_use"

    var displayName: String {
        switch self {
        case .sealed: "# 全新未拆封"
        case .inUse: "# 已开封消耗中"
        }
    }
}
