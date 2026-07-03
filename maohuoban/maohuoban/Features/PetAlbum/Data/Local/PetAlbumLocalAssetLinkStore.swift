import Foundation

// PetAlbumLocalAssetLinkStore 相册本机照片映射存储
// 核心职责：
// - 提供按用户和相册隔离的本机映射读写能力
// - 让业务 Store 在命令边界持久化和恢复禁选集合
protocol PetAlbumLocalAssetLinkStore: AnyObject {
    func links(userID: String, albumID: String) -> [PetAlbumLocalAssetLink]
    func upsert(_ link: PetAlbumLocalAssetLink)
    func remove(userID: String, albumID: String, serverAssetID: String)
    func removeAlbum(userID: String, albumID: String)
}
