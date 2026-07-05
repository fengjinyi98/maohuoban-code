import Foundation

// PantryItem 食品资产展示映射
// 核心职责：
// - 将后端食品资产转换为储物柜页面展示模型
// - 隔离旧 Pantry UI 与空间级食品资产模型差异
extension PantryItem {
    init(foodInventoryItem item: FoodInventoryItem) {
        self.init(
            id: item.id,
            name: item.name,
            brand: item.brand?.isEmpty == false ? item.brand ?? "未填写品牌" : "未填写品牌",
            coverAssetID: item.coverAssetID,
            imageURL: item.coverURL,
            category: PantryCategory(foodInventoryCategory: item.category),
            status: PantryStatus(foodInventoryStatus: item.inventoryStatus),
            statusDate: String(item.updatedAt.prefix(10)),
            statusLabel: item.inventoryStatus.pantryStatusLabel,
            quantity: item.quantity,
            unit: item.unit,
            spec: item.spec,
            expiryDate: item.expiryDate
        )
    }
}

// FoodInventoryDraft 储物柜表单映射
// 核心职责：
// - 将旧储物柜添加表单转换为后端食品资产草稿
extension FoodInventoryDraft {
    init(pantryDraft draft: PantryItemDraft) {
        self.init(
            name: draft.name,
            brand: draft.brand,
            category: FoodInventoryCategory(pantryCategory: draft.category),
            initialStatus: FoodInventoryStatus(pantryInitialStatus: draft.initialStatus),
            quantity: Int(draft.initialStock) ?? 1,
            unit: "件",
            spec: draft.specification,
            expiryDate: draft.expiryInfo,
            coverAssetID: nil,
            note: ""
        )
    }

    init(pantryItem item: PantryItem) {
        self.init(
            name: item.name,
            brand: item.brand == "未填写品牌" ? "" : item.brand,
            category: FoodInventoryCategory(pantryCategory: item.category),
            initialStatus: FoodInventoryStatus(pantryStatus: item.status),
            quantity: item.quantity,
            unit: item.unit ?? "件",
            spec: item.spec ?? "",
            expiryDate: item.expiryDate ?? "",
            coverAssetID: item.coverAssetID,
            note: ""
        )
    }
}

private extension PantryStatus {
    init(foodInventoryStatus status: FoodInventoryStatus) {
        switch status {
        case .sealed:
            self = .sealed
        case .active, .inUse:
            self = .inUse
        case .depleted, .archived:
            self = .periodic
        }
    }
}

private extension FoodInventoryStatus {
    var pantryStatusLabel: String {
        switch self {
        case .active, .inUse:
            "# 消耗中"
        case .sealed:
            "# 未拆封囤货"
        case .depleted:
            "# 已用完"
        case .archived:
            "# 已归档"
        }
    }
}

private extension FoodInventoryCategory {
    init(pantryCategory category: PantryCategory) {
        switch category {
        case .mainFood:
            self = .mainFood
        case .wetFood:
            self = .wetFood
        case .treats:
            self = .treats
        case .supplements:
            self = .nutrition
        case .catLitter:
            self = .catLitter
        case .medicine:
            self = .medicine
        case .all, .other:
            self = .other
        }
    }
}

private extension FoodInventoryStatus {
    init(pantryInitialStatus status: PantryItemInitialStatus) {
        switch status {
        case .sealed:
            self = .sealed
        case .inUse:
            self = .inUse
        }
    }

    init(pantryStatus status: PantryStatus) {
        switch status {
        case .sealed:
            self = .sealed
        case .inUse:
            self = .inUse
        case .periodic:
            self = .depleted
        }
    }
}
