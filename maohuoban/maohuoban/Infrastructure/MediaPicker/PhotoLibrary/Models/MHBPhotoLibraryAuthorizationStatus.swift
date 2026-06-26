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
