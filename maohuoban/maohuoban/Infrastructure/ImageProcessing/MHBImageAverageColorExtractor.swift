import CoreImage.CIFilterBuiltins
import UIKit

// MHBImageAverageColorExtractor 图片平均色提取工具
// 核心职责：
// - 从图片纵向分段提取平均色
// - 为沉浸式背景、渐变和主题氛围提供基础色值能力
enum MHBImageAverageColorExtractor {
    // ScaledToFillVisibleBandColorSample scaledToFill 可见区域分段色值样本
    // 核心职责：
    // - 描述 SwiftUI scaledToFill 后可见区域的纵向分段色值
    // - 为沉浸式头图融合调试提供可定位的色彩证据
    struct ScaledToFillVisibleBandColorSample {
        let label: String
        let startRatio: CGFloat
        let endRatio: CGFloat
        let cropRect: CGRect
        let color: UIColor
    }

    static func extractVerticalColors(
        from image: UIImage,
        count: Int,
        maxDimension: CGFloat = 200
    ) -> [UIColor] {
        guard count > 0 else {
            return []
        }

        return extractColors(
            image: downsample(image: image, maxDimension: maxDimension),
            count: count
        )
    }

    static func extractHighestAverageColor(
        from image: UIImage,
        segmentsCount: Int = 5,
        maxDimension: CGFloat = 200
    ) -> UIColor? {
        let colors = extractVerticalColors(from: image, count: segmentsCount, maxDimension: maxDimension)
        guard !colors.isEmpty else { return nil }

        // 寻找 RGB 亮度平均值最高的色值 (即 (R+G+B)/3 最大的颜色)
        return colors.max { color1, color2 in
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

            color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

            let avg1 = (r1 + g1 + b1) / 3.0
            let avg2 = (r2 + g2 + b2) / 3.0

            return avg1 < avg2
        }
    }

    static func extractScaledToFillVisibleBottomColor(
        from image: UIImage,
        targetSize: CGSize,
        sampleHeightRatio: CGFloat,
        maxDimension: CGFloat = 400
    ) -> UIColor? {
        guard
            targetSize.width > 0,
            targetSize.height > 0,
            sampleHeightRatio > 0
        else {
            return nil
        }

        let preparedImage = downsample(image: image, maxDimension: maxDimension)

        guard let ciImage = CIImage(image: preparedImage) else {
            return nil
        }

        let extent = ciImage.extent
        let scale = max(targetSize.width / extent.width, targetSize.height / extent.height)
        let visibleWidth = targetSize.width / scale
        let visibleHeight = targetSize.height / scale
        let visibleX = extent.midX - visibleWidth / 2
        let visibleY = extent.midY - visibleHeight / 2
        let visibleRect = CGRect(
            x: visibleX,
            y: visibleY,
            width: visibleWidth,
            height: visibleHeight
        ).intersection(extent)
        let sampleHeight = min(visibleRect.height * sampleHeightRatio, visibleRect.height)
        let sampleRect = CGRect(
            x: visibleRect.minX,
            y: visibleRect.minY,
            width: visibleRect.width,
            height: sampleHeight
        )

        return extractAverageColor(
            ciImage: ciImage,
            cropRect: sampleRect
        )
    }

    static func extractScaledToFillVisibleBandColors(
        from image: UIImage,
        targetSize: CGSize,
        bands: [(label: String, startRatio: CGFloat, endRatio: CGFloat)],
        maxDimension: CGFloat = 400
    ) -> [ScaledToFillVisibleBandColorSample] {
        guard targetSize.width > 0, targetSize.height > 0 else {
            return []
        }

        let preparedImage = downsample(image: image, maxDimension: maxDimension)

        guard let ciImage = CIImage(image: preparedImage) else {
            return []
        }

        let extent = ciImage.extent
        let scale = max(targetSize.width / extent.width, targetSize.height / extent.height)
        let visibleWidth = targetSize.width / scale
        let visibleHeight = targetSize.height / scale
        let visibleX = extent.midX - visibleWidth / 2
        let visibleY = extent.midY - visibleHeight / 2
        let visibleRect = CGRect(
            x: visibleX,
            y: visibleY,
            width: visibleWidth,
            height: visibleHeight
        ).intersection(extent)
        let context = CIContext()

        return bands.compactMap { band in
            let startRatio = min(max(band.startRatio, 0), 1)
            let endRatio = min(max(band.endRatio, startRatio), 1)
            let cropTopY = visibleRect.maxY - visibleRect.height * startRatio
            let cropBottomY = visibleRect.maxY - visibleRect.height * endRatio
            let cropRect = CGRect(
                x: visibleRect.minX,
                y: cropBottomY,
                width: visibleRect.width,
                height: max(cropTopY - cropBottomY, 1)
            ).intersection(visibleRect)

            guard let color = extractAverageColor(
                ciImage: ciImage,
                cropRect: cropRect,
                context: context
            ) else {
                return nil
            }

            return ScaledToFillVisibleBandColorSample(
                label: band.label,
                startRatio: startRatio,
                endRatio: endRatio,
                cropRect: cropRect,
                color: color
            )
        }
    }

    private static func downsample(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let imageSize = image.size
        let longestSide = max(imageSize.width, imageSize.height)

        guard longestSide > maxDimension else {
            return image
        }

        let scale = maxDimension / longestSide
        let newSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        let renderFormat = UIGraphicsImageRendererFormat()
        renderFormat.scale = 1

        let downsampledImage = UIGraphicsImageRenderer(size: newSize, format: renderFormat).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return downsampledImage
    }

    private static func extractColors(image: UIImage, count: Int) -> [UIColor] {
        guard let ciImage = CIImage(image: image) else {
            return []
        }

        let extent = ciImage.extent
        let tileHeight = extent.height / CGFloat(count)
        let context = CIContext()

        return (0..<count).compactMap { index -> UIColor? in
            let cropRect = CGRect(
                x: extent.origin.x,
                y: extent.height - CGFloat(index + 1) * tileHeight,
                width: extent.width,
                height: tileHeight
            )

            return extractAverageColor(
                ciImage: ciImage,
                cropRect: cropRect,
                context: context
            )
        }
    }

    private static func extractAverageColor(
        ciImage: CIImage,
        cropRect: CGRect,
        context: CIContext = CIContext()
    ) -> UIColor? {
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = cropRect

        guard let outputImage = filter.outputImage else {
            return nil
        }

        var bytes = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bytes,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return UIColor(
            red: CGFloat(bytes[0]) / 255,
            green: CGFloat(bytes[1]) / 255,
            blue: CGFloat(bytes[2]) / 255,
            alpha: CGFloat(bytes[3]) / 255
        )
    }
}
