import UIKit

// MHBMediaPickerResult 媒体选择结果
// 核心职责：
// - 承载本轮选择解析后的本地媒体内容
// - 为图片、视频和 Live Photo 选择结果提供统一边界
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

    var isEmpty: Bool {
        images.isEmpty && videos.isEmpty && livePhotos.isEmpty
    }

    static func merging(_ results: [MHBMediaPickerResult]) -> MHBMediaPickerResult {
        MHBMediaPickerResult(
            images: results.flatMap(\.images),
            videos: results.flatMap(\.videos),
            livePhotos: results.flatMap(\.livePhotos)
        )
    }
}
