import Foundation

// FoodInventoryItem 储物柜食品资产（与后端 food_inventory_items 对齐）
// 核心职责：
// - 表达空间级储物柜食品资产，供多宠共用
// - 支持分类、库存状态和来源追踪
struct FoodInventoryItem: Identifiable, Codable, Equatable {
    let id: String
    let scopeType: String
    let scopeID: String
    let createdByUserID: String
    let name: String
    let brand: String?
    let category: FoodInventoryCategory
    let inventoryStatus: FoodInventoryStatus
    let quantity: Int
    let unit: String?
    let spec: String?
    let expiryDate: String?
    let coverAssetID: String?
    let coverURL: String?
    let barcode: String?
    let sourceKind: String
    let note: String?
    let createdAt: String
    let updatedAt: String
    let archivedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case scopeType = "scope_type"
        case scopeID = "scope_id"
        case createdByUserID = "created_by_user_id"
        case name, brand, category
        case inventoryStatus = "inventory_status"
        case quantity, unit, spec
        case expiryDate = "expiry_date"
        case coverAssetID = "cover_asset_id"
        case coverURL = "cover_url"
        case barcode
        case sourceKind = "source_kind"
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }

    init(
        id: String,
        scopeType: String,
        scopeID: String,
        createdByUserID: String,
        name: String,
        brand: String?,
        category: FoodInventoryCategory,
        inventoryStatus: FoodInventoryStatus,
        quantity: Int,
        unit: String?,
        spec: String?,
        expiryDate: String?,
        coverAssetID: String?,
        coverURL: String? = nil,
        barcode: String?,
        sourceKind: String,
        note: String?,
        createdAt: String,
        updatedAt: String,
        archivedAt: String?
    ) {
        self.id = id
        self.scopeType = scopeType
        self.scopeID = scopeID
        self.createdByUserID = createdByUserID
        self.name = name
        self.brand = brand
        self.category = category
        self.inventoryStatus = inventoryStatus
        self.quantity = quantity
        self.unit = unit
        self.spec = spec
        self.expiryDate = expiryDate
        self.coverAssetID = coverAssetID
        self.coverURL = coverURL
        self.barcode = barcode
        self.sourceKind = sourceKind
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
    }
}

/// FoodInventoryCategory 食品分类（与后端枚举对齐）
enum FoodInventoryCategory: String, Codable, Equatable, CaseIterable {
    case mainFood = "main_food"
    case wetFood = "wet_food"
    case treats = "treats"
    case nutrition = "nutrition"
    case other = "other"
    case catLitter = "cat_litter"
    case medicine = "medicine"

    var displayName: String {
        switch self {
        case .mainFood: "主食干粮"
        case .wetFood: "湿粮/罐头"
        case .treats: "零食奖励"
        case .nutrition: "营养保健"
        case .other: "其他"
        case .catLitter: "猫砂"
        case .medicine: "药品"
        }
    }
}

/// FoodInventoryStatus 库存状态（与后端枚举对齐）
enum FoodInventoryStatus: String, Codable, Equatable, CaseIterable {
    case active = "active"
    case sealed = "sealed"
    case inUse = "in_use"
    case depleted = "depleted"
    case archived = "archived"

    static var editableCases: [FoodInventoryStatus] {
        [.active, .sealed, .inUse, .depleted]
    }

    var displayLabel: String {
        switch self {
        case .active: "在用"
        case .sealed: "未拆封"
        case .inUse: "消耗中"
        case .depleted: "已用完"
        case .archived: "已归档"
        }
    }
}

// FoodInventoryDraft 食品资产表单草稿
// 核心职责：
// - 承载添加/编辑食品资产时的表单状态
struct FoodInventoryDraft {
    var name: String = ""
    var brand: String = ""
    var category: FoodInventoryCategory = .mainFood
    var initialStatus: FoodInventoryStatus = .sealed
    var quantity: Int = 1
    var unit: String = ""
    var spec: String = ""
    var expiryDate: String = ""
    var coverAssetID: String?
    var note: String = ""

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
