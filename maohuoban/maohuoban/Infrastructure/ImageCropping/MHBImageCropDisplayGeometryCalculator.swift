import CoreGraphics

// MHBImageCropDisplayGeometryCalculator 图片裁剪展示几何计算器
// 核心职责：
// - 计算裁剪页进入时的图片展示尺寸
// - 避免小图被主动放大，大图按比例缩小到视口内展示
enum MHBImageCropDisplayGeometryCalculator {
    static func initialDisplaySize(
        imagePointSize: CGSize,
        viewportSize: CGSize,
        minimumCoverSize: CGSize? = nil
    ) -> CGSize {
        let imageWidth = max(imagePointSize.width, 1)
        let imageHeight = max(imagePointSize.height, 1)
        let viewportWidth = max(viewportSize.width, 1)
        let viewportHeight = max(viewportSize.height, 1)
        let fitScale = min(1, viewportWidth / imageWidth, viewportHeight / imageHeight)

        let coverScale: CGFloat
        if let minimumCoverSize {
            coverScale = max(
                max(minimumCoverSize.width, 1) / imageWidth,
                max(minimumCoverSize.height, 1) / imageHeight
            )
        } else {
            coverScale = 0
        }

        let scale = max(fitScale, coverScale)

        return CGSize(
            width: imageWidth * scale,
            height: imageHeight * scale
        )
    }
}
