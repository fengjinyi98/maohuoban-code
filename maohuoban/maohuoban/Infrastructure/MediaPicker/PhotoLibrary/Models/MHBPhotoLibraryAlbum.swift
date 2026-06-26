import Photos

// MHBPhotoLibraryAlbum 照片库相册模型
// 核心职责：
// - 承载 PhotoKit 相册引用和展示字段
// - 为 SwiftUI 相册列表提供稳定身份
struct MHBPhotoLibraryAlbum: Identifiable, Equatable {
    let id: String
    let title: String
    let assetCount: Int
    let subtype: PHAssetCollectionSubtype
    let collection: PHAssetCollection

    init(collection: PHAssetCollection, assetCount: Int) {
        self.id = collection.localIdentifier
        self.title = collection.localizedTitle ?? "未命名相册"
        self.assetCount = assetCount
        self.subtype = collection.assetCollectionSubtype
        self.collection = collection
    }

    static func == (lhs: MHBPhotoLibraryAlbum, rhs: MHBPhotoLibraryAlbum) -> Bool {
        lhs.id == rhs.id
    }
}
