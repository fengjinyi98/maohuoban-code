import Foundation

// PetMediaBinding 宠物媒体绑定
// 核心职责：
// - 表达媒体资产与宠物业务用途的生效关系
// - 支持替换和清理链路追溯
struct PetMediaBinding: Decodable, Equatable, Identifiable {
    let id: String
    let assetID: String
    let petID: String
    let usageKind: PetMediaUsageKind
    let status: PetMediaBindingStatus
    let boundByUserID: String?
    let boundAt: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case assetID = "asset_id"
        case petID = "pet_id"
        case usageKind = "usage_kind"
        case status
        case boundByUserID = "bound_by_user_id"
        case boundAt = "bound_at"
        case createdAt = "created_at"
    }
}
