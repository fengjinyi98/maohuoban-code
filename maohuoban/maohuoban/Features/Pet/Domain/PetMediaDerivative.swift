import Foundation

// PetMediaDerivative 宠物媒体派生资源
// 核心职责：
// - 承接缩略图、视频封面帧和主题色派生记录
// - 为上传完成后的派生状态展示提供稳定字段
struct PetMediaDerivative: Decodable, Equatable, Identifiable {
    let id: String
    let parentAssetID: String
    let derivativeKind: PetMediaDerivativeKind
    let bucket: String
    let objectKey: String
    let mimeType: String
    let byteSize: Int
    let sha256Hex: String
    let metadata: PetMediaDerivativeMetadata
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case parentAssetID = "parent_asset_id"
        case derivativeKind = "derivative_kind"
        case bucket
        case objectKey = "object_key"
        case mimeType = "mime_type"
        case byteSize = "byte_size"
        case sha256Hex = "sha256_hex"
        case metadata
        case createdAt = "created_at"
    }
}

// PetMediaDerivativeMetadata 宠物媒体派生元数据
// 核心职责：
// - 承接主题色与派生图尺寸
// - 隔离后端 metadata 的 snake_case 字段
struct PetMediaDerivativeMetadata: Decodable, Equatable {
    let themeColorHex: String?
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case themeColorHex = "theme_color_hex"
        case width
        case height
    }

    init(themeColorHex: String? = nil, width: Int? = nil, height: Int? = nil) {
        self.themeColorHex = themeColorHex
        self.width = width
        self.height = height
    }
}
