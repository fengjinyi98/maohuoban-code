import Foundation

// PantryItem 储物柜物品
// 核心职责：
// - 表达单个食品或用品的完整信息
// - 支持分类、状态和日期管理
struct PantryItem: Identifiable, Decodable, Equatable, Hashable {
    let id: String
    let name: String
    let brand: String
    let coverAssetID: String?
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
        case coverAssetID = "cover_asset_id"
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
