import CoreGraphics

// MHBRectImageCropGeometryCalculator 矩形图片裁剪几何计算器
// 核心职责：
// - 将屏幕中的矩形裁剪框换算到原图像素坐标系
// - 为背景图片裁剪页提供可复用的纯函数计算能力
enum MHBRectImageCropGeometryCalculator {
    static func cropRect(
        imagePixelSize: CGSize,
        viewportSize: CGSize,
        imageScale: CGFloat,
        imageOffset: CGSize,
        cropFrameSize: CGSize
    ) -> CGRect {
        let imageAspectRatio = imagePixelSize.width / imagePixelSize.height
        let viewportAspectRatio = viewportSize.width / viewportSize.height

        let baseDisplayWidth: CGFloat
        let baseDisplayHeight: CGFloat
        if viewportAspectRatio > imageAspectRatio {
            baseDisplayWidth = viewportSize.width
            baseDisplayHeight = baseDisplayWidth / imageAspectRatio
        } else {
            baseDisplayHeight = viewportSize.height
            baseDisplayWidth = baseDisplayHeight * imageAspectRatio
        }

        let displayWidth = baseDisplayWidth * imageScale
        let imageCenterX = viewportSize.width / 2 + imageOffset.width
        let imageCenterY = viewportSize.height / 2 + imageOffset.height
        let screenCenterX = viewportSize.width / 2
        let screenCenterY = viewportSize.height / 2
        let deltaX = screenCenterX - imageCenterX
        let deltaY = screenCenterY - imageCenterY
        let pixelScale = imagePixelSize.width / displayWidth
        let cropWidth = cropFrameSize.width * pixelScale
        let cropHeight = cropFrameSize.height * pixelScale
        let cropCenterX = imagePixelSize.width / 2 + deltaX * pixelScale
        let cropCenterY = imagePixelSize.height / 2 + deltaY * pixelScale

        return CGRect(
            x: cropCenterX - cropWidth / 2,
            y: cropCenterY - cropHeight / 2,
            width: cropWidth,
            height: cropHeight
        )
    }
}
