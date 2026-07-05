import Foundation

// PantryItemFormMode 储物柜物品表单模式
// 核心职责：
// - 区分添加入口和编辑入口
// - 为单一物品表单页面提供初始草稿和保存语义
enum PantryItemFormMode: Hashable {
    case create
    case edit(FoodInventoryItem)

    var title: String {
        switch self {
        case .create:
            "新资产入库"
        case .edit:
            "编辑物品信息"
        }
    }

    var saveTitle: String {
        switch self {
        case .create:
            "完成"
        case .edit:
            "保存"
        }
    }

    var existingImageURL: String? {
        switch self {
        case .create:
            nil
        case .edit(let item):
            item.coverURL
        }
    }

    var initialDraft: FoodInventoryDraft {
        switch self {
        case .create:
            FoodInventoryDraft(unit: "件")
        case .edit(let item):
            FoodInventoryDraft(foodInventoryItem: item)
        }
    }
}
