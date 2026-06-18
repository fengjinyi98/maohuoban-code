import SwiftUI
import UIKit

extension PetProfileBackgroundPreviewScreen {
    // handleImagePickerResult 处理背景图片选择结果
    // 核心职责：
    // - 对图片和 Live Photo 预览图进入裁剪流程
    // - 缺少预览图的 Live Photo 直接保存草稿
    func handleImagePickerResult(_ result: MHBMediaPickerResult) {
        if let livePhoto = result.livePhotos.first {
            guard let previewImage = livePhoto.previewImage else {
                saveHeroMedia(.livePhoto(livePhoto))
                return
            }
            cropTarget = PetProfileBackgroundCropTarget(
                image: previewImage,
                source: .livePhoto(livePhoto)
            )
            return
        }

        guard let image = result.images.first else {
            return
        }

        cropTarget = PetProfileBackgroundCropTarget(
            image: image,
            source: .image
        )
    }

    // handleVideoPickerResult 处理背景视频选择结果
    // 核心职责：
    // - 对视频草稿直接保存
    // - 对 Live Photo 复用背景裁剪流程
    func handleVideoPickerResult(_ result: MHBMediaPickerResult) {
        if let livePhoto = result.livePhotos.first {
            guard let previewImage = livePhoto.previewImage else {
                saveHeroMedia(.livePhoto(livePhoto))
                return
            }
            cropTarget = PetProfileBackgroundCropTarget(
                image: previewImage,
                source: .livePhoto(livePhoto)
            )
            return
        }

        guard let video = result.videos.first else {
            return
        }
        saveHeroMedia(.video(video.url))
    }

    // handleCroppedBackground 处理背景裁剪结果
    // 核心职责：
    // - 将裁剪图片写回图片草稿
    // - 为 Live Photo 草稿附带裁剪元数据
    func handleCroppedBackground(
        _ result: MHBRectImageCropResult,
        target: PetProfileBackgroundCropTarget
    ) {
        cropTarget = nil
        switch target.source {
        case .image:
            saveHeroMedia(.image(result.image))
        case .livePhoto(let livePhoto):
            saveHeroMedia(
                .livePhoto(
                    livePhoto.applyingCrop(
                        previewImage: result.image,
                        metadata: result.metadata
                    )
                )
            )
        }
    }

    // saveHeroMedia 保存背景媒体草稿
    // 核心职责：
    // - 先更新本地预览
    // - 再提交外部保存回调并同步保存状态
    func saveHeroMedia(_ media: PetProfileHeroMediaDraft) {
        previewMedia = media
        uploadState = .uploading

        Task { @MainActor in
            let didSave = await onHeroMediaUpdated(media)
            uploadState = didSave ? .saved : .idle
        }
    }
}
