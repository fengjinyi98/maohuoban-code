import Foundation
import UIKit

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
