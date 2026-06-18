import UIKit

// PetProfileBackgroundCropTarget 宠物背景裁剪目标
// 核心职责：
// - 区分普通图片裁剪和 Live Photo 静态预览裁剪
// - 为背景预览页保存裁剪结果后恢复原始媒体上下文
struct PetProfileBackgroundCropTarget: Identifiable {
    enum Source {
        case image
        case livePhoto(MHBPickedLivePhoto)
    }

    let id = UUID()
    let image: UIImage
    let source: Source
}
