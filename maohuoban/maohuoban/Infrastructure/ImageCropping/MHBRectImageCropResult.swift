import UIKit

// MHBRectImageCropResult 矩形裁剪结果
// 核心职责：
// - 承载裁剪后的静态图片
// - 同步提供原图坐标系下的归一化裁剪元数据
struct MHBRectImageCropResult {
    let image: UIImage
    let metadata: MHBImageCropMetadata
}
