import Photos

// MHBPhotoLibraryAsset 照片库资源模型
// 核心职责：
// - 封装 PhotoKit 媒体资源
// - 暴露照片、视频和 Live Photo 标识给网格 UI
struct MHBPhotoLibraryAsset: Identifiable, Hashable {
    let id: String
    let asset: PHAsset
    let isLivePhoto: Bool
    let isVideo: Bool
    let duration: TimeInterval?

    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.isLivePhoto = asset.mediaSubtypes.contains(.photoLive)
        self.isVideo = asset.mediaType == .video
        self.duration = asset.mediaType == .video ? asset.duration : nil
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MHBPhotoLibraryAsset, rhs: MHBPhotoLibraryAsset) -> Bool {
        lhs.id == rhs.id
    }
}
