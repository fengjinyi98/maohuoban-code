import Foundation

// PetPantrySummary 宠物储物柜摘要
// 核心职责：
// - 承载首页展示的储物柜统计信息
// - 提供最后添加日期和物品总数
struct PetPantrySummary: Decodable, Equatable {
    let totalItems: Int
    let lastAddedDate: String

    enum CodingKeys: String, CodingKey {
        case totalItems = "total_items"
        case lastAddedDate = "last_added_date"
    }

    static let mock = PetPantrySummary(
        totalItems: 12,
        lastAddedDate: "2026.06.24"
    )
}

// PantryItem 储物柜物品
// 核心职责：
// - 表达单个食品或用品的完整信息
// - 支持分类、状态和日期管理
struct PantryItem: Identifiable, Decodable, Equatable {
    let id: String
    let name: String
    let brand: String
    let imageURL: String?
    let category: PantryCategory
    let status: PantryStatus
    let statusDate: String
    let statusLabel: String
    let quantity: Int
    let unit: String?
    let spec: String?
    let expiryDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case brand
        case imageURL = "image_url"
        case category
        case status
        case statusDate = "status_date"
        case statusLabel = "status_label"
        case quantity
        case unit
        case spec
        case expiryDate = "expiry_date"
    }
}

// PantryCategory 储物柜分类
// 核心职责：
// - 约束物品分类枚举
// - 支持筛选栏展示
enum PantryCategory: String, Decodable, Equatable, CaseIterable {
    case all = "all"
    case mainFood = "main_food"
    case wetFood = "wet_food"
    case treats = "treats"
    case supplements = "supplements"
    case catLitter = "cat_litter"
    case medicine = "medicine"

    var displayName: String {
        switch self {
        case .all: "全部"
        case .mainFood: "主食干粮"
        case .wetFood: "湿粮/罐头"
        case .treats: "零食奖励"
        case .supplements: "营养保健"
        case .catLitter: "猫砂"
        case .medicine: "药品"
        }
    }
}

// PantryStatus 储物柜物品状态
// 核心职责：
// - 表达物品当前使用状态
// - 支持标签样式区分
enum PantryStatus: String, Decodable, Equatable {
    case inUse = "in_use"
    case sealed = "sealed"
    case periodic = "periodic"

    var isGrayTag: Bool {
        self == .sealed || self == .periodic
    }
}
