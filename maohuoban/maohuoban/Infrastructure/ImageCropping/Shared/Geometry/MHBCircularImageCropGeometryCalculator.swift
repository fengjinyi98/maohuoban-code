import CoreGraphics

// MHBCircularImageCropGeometryCalculator 圆形图片裁剪几何计算器
// 核心职责：
// - 将屏幕中的圆形裁剪框换算到原图像素坐标系
// - 为头像裁剪页提供可复用的纯函数计算能力
enum MHBCircularImageCropGeometryCalculator {
    // boundedIntegralCropRect 圆形裁剪像素边界约束
    // 核心职责：
    // - 将浮点裁剪框扩展为整数像素框
    // - 消除贴边裁剪时的浮点误差越界
    static func boundedIntegralCropRect(
        _ cropRect: CGRect,
        imagePixelSize: CGSize
    ) -> CGRect {
        let integralRect = cropRect.integral
        let sideLength = min(
            integralRect.width,
            integralRect.height,
            imagePixelSize.width,
            imagePixelSize.height
        )
        let maxX = max(imagePixelSize.width - sideLength, 0)
        let maxY = max(imagePixelSize.height - sideLength, 0)
        let originX = min(max(integralRect.origin.x, 0), maxX)
        let originY = min(max(integralRect.origin.y, 0), maxY)

        return CGRect(
            x: originX,
            y: originY,
            width: sideLength,
            height: sideLength
        )
    }

    static func cropRect(
        imagePixelSize: CGSize,
        imageDisplaySize: CGSize,
        viewportSize: CGSize,
        imageScale: CGFloat,
        imageOffset: CGSize,
        cropRadius: CGFloat
    ) -> CGRect {
        let displayWidth = max(imageDisplaySize.width, 1) * max(imageScale, 0.0001)
        let imageCenterX = viewportSize.width / 2 + imageOffset.width
        let imageCenterY = viewportSize.height / 2 + imageOffset.height
        let screenCenterX = viewportSize.width / 2
        let screenCenterY = viewportSize.height / 2
        let deltaX = screenCenterX - imageCenterX
        let deltaY = screenCenterY - imageCenterY
        let pixelScale = imagePixelSize.width / displayWidth
        let cropRadiusInImage = cropRadius * pixelScale
        let cropCenterX = imagePixelSize.width / 2 + deltaX * pixelScale
        let cropCenterY = imagePixelSize.height / 2 + deltaY * pixelScale

        return CGRect(
            x: cropCenterX - cropRadiusInImage,
            y: cropCenterY - cropRadiusInImage,
            width: cropRadiusInImage * 2,
            height: cropRadiusInImage * 2
        )
    }
}
