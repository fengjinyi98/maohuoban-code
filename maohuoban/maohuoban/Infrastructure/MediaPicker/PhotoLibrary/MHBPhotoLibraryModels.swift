import Foundation
import Photos

// MHBPhotoLibraryAuthorizationStatus 照片库授权状态
// 核心职责：
// - 屏蔽 PhotoKit 原始授权枚举
// - 为照片选择器页面提供稳定授权判断
enum MHBPhotoLibraryAuthorizationStatus: Equatable {
    case notDetermined
    case restricted
    case denied
    case authorized
    case limited

    init(_ status: PHAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .limited:
            self = .limited
        @unknown default:
            self = .denied
        }
    }

    var canReadLibrary: Bool {
        self == .authorized || self == .limited
    }
}

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

// MHBPhotoLibraryAsset 照片库资源模型
// 核心职责：
// - 封装 PhotoKit 图片资源
// - 暴露 Live Photo 标识给网格 UI
struct MHBPhotoLibraryAsset: Identifiable, Hashable {
    let id: String
    let asset: PHAsset
    let isLivePhoto: Bool

    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.isLivePhoto = asset.mediaSubtypes.contains(.photoLive)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MHBPhotoLibraryAsset, rhs: MHBPhotoLibraryAsset) -> Bool {
        lhs.id == rhs.id
    }
}
