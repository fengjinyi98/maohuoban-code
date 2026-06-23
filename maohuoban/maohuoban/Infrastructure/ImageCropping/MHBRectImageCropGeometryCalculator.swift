import CoreGraphics

// MHBRectImageCropGeometryCalculator 矩形图片裁剪几何计算器
// 核心职责：
// - 将屏幕中的矩形裁剪框换算到原图像素坐标系
// - 为背景图片裁剪页提供可复用的纯函数计算能力
enum MHBRectImageCropGeometryCalculator {
    static func cropRect(
        imagePixelSize: CGSize,
        imageDisplaySize: CGSize,
        viewportSize: CGSize,
        imageScale: CGFloat,
        imageOffset: CGSize,
        cropFrameSize: CGSize
    ) -> CGRect {
        let effectiveScale = max(imageScale, 0.0001)
        let displayWidth = max(imageDisplaySize.width, 1) * effectiveScale
        let displayHeight = max(imageDisplaySize.height, 1) * effectiveScale
        let imageCenterX = viewportSize.width / 2 + imageOffset.width
        let imageCenterY = viewportSize.height / 2 + imageOffset.height
        let screenCenterX = viewportSize.width / 2
        let screenCenterY = viewportSize.height / 2
        let deltaX = screenCenterX - imageCenterX
        let deltaY = screenCenterY - imageCenterY
        let pixelScaleX = imagePixelSize.width / displayWidth
        let pixelScaleY = imagePixelSize.height / displayHeight
        let cropWidth = cropFrameSize.width * pixelScaleX
        let cropHeight = cropFrameSize.height * pixelScaleY
        let cropCenterX = imagePixelSize.width / 2 + deltaX * pixelScaleX
        let cropCenterY = imagePixelSize.height / 2 + deltaY * pixelScaleY

        return CGRect(
            x: cropCenterX - cropWidth / 2,
            y: cropCenterY - cropHeight / 2,
            width: cropWidth,
            height: cropHeight
        )
    }
}
