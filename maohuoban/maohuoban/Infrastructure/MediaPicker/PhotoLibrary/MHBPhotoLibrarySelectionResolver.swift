import UIKit

// MHBResolvedPhotoLibrarySelection PhotoKit 选择解析输入
// 核心职责：
// - 承载 PhotoKit 单选资源加载后的普通图片或 Live Photo
// - 为解析逻辑提供可测试的纯输入模型
struct MHBResolvedPhotoLibrarySelection {
    let image: UIImage?
    let livePhoto: MHBPickedLivePhoto?
}

// MHBPhotoLibrarySelectionResolver PhotoKit 选择结果解析器
// 核心职责：
// - 将 PhotoKit 单选结果转换为通用媒体选择结果
// - 保证 Live Photo 优先进入原始资源上传链路
enum MHBPhotoLibrarySelectionResolver {
    static func resolve(_ selection: MHBResolvedPhotoLibrarySelection) -> MHBMediaPickerResult {
        if let livePhoto = selection.livePhoto {
            return MHBMediaPickerResult(livePhotos: [livePhoto])
        }

        if let image = selection.image {
            return MHBMediaPickerResult(images: [image])
        }

        return MHBMediaPickerResult()
    }
}
