import UIKit

// MHBCoverImageSelectionResolver 封面图片选择解析器
// 核心职责：
// - 从通用媒体选择结果中提取可用于封面预览的图片
// - 让相册和收藏夹创建页复用一致的封面选择规则
enum MHBCoverImageSelectionResolver {
    static func resolveImage(from result: MHBMediaPickerResult) -> UIImage? {
        if let image = result.images.first {
            return image
        }

        return result.livePhotos.first?.previewImage
    }
}
