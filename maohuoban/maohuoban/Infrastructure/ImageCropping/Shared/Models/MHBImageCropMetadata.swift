import CoreGraphics
import Foundation

// MHBImageCropMetadata 图片裁剪元数据
// 核心职责：
// - 使用归一化坐标描述图片展示裁剪区域
// - 为 Live Photo 保留原始资源的同时提供稳定裁剪契约
struct MHBImageCropMetadata: Codable, Equatable, Hashable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    static func normalized(
        cropRect: CGRect,
        imagePixelSize: CGSize
    ) -> MHBImageCropMetadata {
        let imageBounds = CGRect(origin: .zero, size: imagePixelSize)
        let boundedRect = cropRect.intersection(imageBounds)
        let imageWidth = max(Double(imagePixelSize.width), 1)
        let imageHeight = max(Double(imagePixelSize.height), 1)

        return MHBImageCropMetadata(
            x: clamped(Double(boundedRect.minX) / imageWidth),
            y: clamped(Double(boundedRect.minY) / imageHeight),
            width: clamped(Double(boundedRect.width) / imageWidth),
            height: clamped(Double(boundedRect.height) / imageHeight)
        )
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
