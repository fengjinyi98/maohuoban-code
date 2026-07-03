import Foundation

// PetAlbumLocalAssetLink 相册本机照片映射
// 核心职责：
// - 记录服务端相册资产与当前设备 PhotoKit 资源的轻量关联
// - 支撑退出相册页面后恢复本机已上传照片禁选态
struct PetAlbumLocalAssetLink: Codable, Equatable, Hashable {
    let userID: String
    let albumID: String
    let serverAssetID: String
    let localIdentifier: String
    let fingerprint: String?
    let createdAt: Date
}
