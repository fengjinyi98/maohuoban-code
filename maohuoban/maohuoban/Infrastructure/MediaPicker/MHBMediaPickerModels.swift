import Foundation
import PhotosUI
import UIKit

// MHBMediaPickerFilter 媒体选择过滤条件
// 核心职责：
// - 描述业务发起媒体选择时允许选择的资源类型
// - 为系统 PHPicker 过滤器提供稳定转换入口
enum MHBMediaPickerFilter: Hashable {
    case images
    case videos
    case videosAndLivePhotos
    case all

    var pickerFilter: PHPickerFilter? {
        switch self {
        case .images:
            return .images
        case .videos:
            return .videos
        case .videosAndLivePhotos:
            return .any(of: [.videos, .livePhotos])
        case .all:
            return .any(of: [.images, .videos, .livePhotos])
        }
    }
}

// MHBMediaPickerRequest 媒体选择请求
// 核心职责：
// - 统一描述媒体选择器的选择数量和类型约束
// - 为头像、背景和后续 UGC 发布流程提供共用入口
struct MHBMediaPickerRequest: Hashable {
    let maxSelectionCount: Int
    let filter: MHBMediaPickerFilter

    static let singleImage = MHBMediaPickerRequest(
        maxSelectionCount: 1,
        filter: .images
    )

    static let singleVideo = MHBMediaPickerRequest(
        maxSelectionCount: 1,
        filter: .videos
    )

    static let singleVideoOrLivePhoto = MHBMediaPickerRequest(
        maxSelectionCount: 1,
        filter: .videosAndLivePhotos
    )

    init(
        maxSelectionCount: Int,
        filter: MHBMediaPickerFilter
    ) {
        self.maxSelectionCount = max(maxSelectionCount, 1)
        self.filter = filter
    }
}

// MHBMediaPickerResult 媒体选择结果
// 核心职责：
// - 承载本轮选择解析后的本地媒体内容
// - 为后续扩展视频资源和多选发布保留结果边界
struct MHBMediaPickerResult {
    let images: [UIImage]
    let videos: [MHBPickedVideo]
    let livePhotos: [MHBPickedLivePhoto]

    init(
        images: [UIImage] = [],
        videos: [MHBPickedVideo] = [],
        livePhotos: [MHBPickedLivePhoto] = []
    ) {
        self.images = images
        self.videos = videos
        self.livePhotos = livePhotos
    }
}

// MHBPickedVideo 已选择视频资源
// 核心职责：
// - 承载从系统相册复制到本地临时目录的视频 URL
// - 为背景视频和后续 UGC 视频发布提供统一结果模型
struct MHBPickedVideo: Identifiable, Hashable {
    let id = UUID()
    let url: URL
}

// MHBPickedLivePhoto 已选择 Live Photo 资源
// 核心职责：
// - 承载 Live Photo 静态图和配对视频的临时文件 URL
// - 为背景上传保留原始成对资源
struct MHBPickedLivePhoto: Identifiable {
    let id = UUID()
    let stillURL: URL
    let pairedVideoURL: URL
    let previewImage: UIImage?
    let cropMetadata: MHBImageCropMetadata?

    init(
        stillURL: URL,
        pairedVideoURL: URL,
        previewImage: UIImage?,
        cropMetadata: MHBImageCropMetadata? = nil
    ) {
        self.stillURL = stillURL
        self.pairedVideoURL = pairedVideoURL
        self.previewImage = previewImage
        self.cropMetadata = cropMetadata
    }

    func applyingCrop(
        previewImage: UIImage,
        metadata: MHBImageCropMetadata
    ) -> MHBPickedLivePhoto {
        MHBPickedLivePhoto(
            stillURL: stillURL,
            pairedVideoURL: pairedVideoURL,
            previewImage: previewImage,
            cropMetadata: metadata
        )
    }
}

// MHBIdentifiableUIImage 可识别本地图片
// 核心职责：
// - 为 fullScreenCover item 传递本地图片提供稳定身份
// - 避免业务页面重复定义图片包装模型
struct MHBIdentifiableUIImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
