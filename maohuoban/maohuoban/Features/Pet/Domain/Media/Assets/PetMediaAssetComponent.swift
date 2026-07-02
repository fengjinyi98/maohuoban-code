import Foundation

// PetMediaAssetComponent 组合媒体资产组件
// 核心职责：
// - 承接 Live Photo 静态图和配对视频的组件级元数据
// - 为前端重建组合媒体提供 URL、尺寸和时长
struct PetMediaAssetComponent: Decodable, Equatable, Identifiable {
    let id: String
    let assetID: String
    let url: String
    let componentKind: PetMediaAssetComponentKind
    let bucket: String
    let objectKey: String
    let mimeType: String
    let byteSize: Int
    let sha256Hex: String
    let width: Int?
    let height: Int?
    let durationMS: Int?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case assetID = "asset_id"
        case url
        case componentKind = "component_kind"
        case bucket
        case objectKey = "object_key"
        case mimeType = "mime_type"
        case byteSize = "byte_size"
        case sha256Hex = "sha256_hex"
        case width
        case height
        case durationMS = "duration_ms"
        case createdAt = "created_at"
    }
}
