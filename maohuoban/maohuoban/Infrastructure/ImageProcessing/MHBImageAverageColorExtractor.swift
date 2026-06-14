import CoreImage.CIFilterBuiltins
import UIKit

// MHBImageAverageColorExtractor 图片平均色提取工具
// 核心职责：
// - 从图片纵向分段提取平均色
// - 为沉浸式背景、渐变和主题氛围提供基础色值能力
enum MHBImageAverageColorExtractor {
    static func extractVerticalColors(
        from image: UIImage,
        count: Int,
        maxDimension: CGFloat = 200,
        debugTag: String? = nil
    ) -> [UIColor] {
        debugLog(
            tag: debugTag,
            "extractVerticalColors start count=\(count), maxDimension=\(debugNumber(maxDimension)), imageSize=\(debugSize(image.size))"
        )

        guard count > 0 else {
            debugLog(tag: debugTag, "extractVerticalColors aborted because count <= 0")
            return []
        }

        return extractColors(
            image: downsample(image: image, maxDimension: maxDimension, debugTag: debugTag),
            count: count,
            debugTag: debugTag
        )
    }

    static func extractScaledToFillVisibleBottomColor(
        from image: UIImage,
        targetSize: CGSize,
        sampleHeightRatio: CGFloat,
        maxDimension: CGFloat = 400,
        debugTag: String? = nil
    ) -> UIColor? {
        debugLog(
            tag: debugTag,
            "extractScaledToFillVisibleBottomColor start targetSize=\(debugSize(targetSize)), sampleHeightRatio=\(debugNumber(sampleHeightRatio)), maxDimension=\(debugNumber(maxDimension))"
        )

        guard
            targetSize.width > 0,
            targetSize.height > 0,
            sampleHeightRatio > 0
        else {
            debugLog(tag: debugTag, "visibleBottomColor aborted because target size or sample ratio is invalid")
            return nil
        }

        let preparedImage = downsample(image: image, maxDimension: maxDimension, debugTag: debugTag)

        guard let ciImage = CIImage(image: preparedImage) else {
            debugLog(tag: debugTag, "visibleBottomColor failed because CIImage init returned nil")
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

        debugLog(
            tag: debugTag,
            "visibleBottomColor extent=\(debugRect(extent)), fillScale=\(debugNumber(scale)), visibleRect=\(debugRect(visibleRect)), sampleRect=\(debugRect(sampleRect))"
        )

        return extractAverageColor(
            ciImage: ciImage,
            cropRect: sampleRect,
            debugTag: debugTag,
            label: "visibleBottomColor"
        )
    }

    private static func downsample(image: UIImage, maxDimension: CGFloat, debugTag: String?) -> UIImage {
        let imageSize = image.size
        let longestSide = max(imageSize.width, imageSize.height)

        guard longestSide > maxDimension else {
            debugLog(tag: debugTag, "downsample skipped longestSide=\(debugNumber(longestSide))")
            return image
        }

        let scale = maxDimension / longestSide
        let newSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        let renderFormat = UIGraphicsImageRendererFormat()
        renderFormat.scale = 1

        debugLog(
            tag: debugTag,
            "downsample resized scale=\(debugNumber(scale)), newSize=\(debugSize(newSize))"
        )

        let downsampledImage = UIGraphicsImageRenderer(size: newSize, format: renderFormat).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        debugLog(tag: debugTag, "downsample finished outputSize=\(debugSize(downsampledImage.size))")
        return downsampledImage
    }

    private static func extractColors(image: UIImage, count: Int, debugTag: String?) -> [UIColor] {
        guard let ciImage = CIImage(image: image) else {
            debugLog(tag: debugTag, "extractColors failed because CIImage init returned nil")
            return []
        }

        let extent = ciImage.extent
        let tileHeight = extent.height / CGFloat(count)
        let context = CIContext()

        debugLog(
            tag: debugTag,
            "extractColors extent=\(debugRect(extent)), tileHeight=\(debugNumber(tileHeight))"
        )

        let colors = (0..<count).compactMap { index -> UIColor? in
            let cropRect = CGRect(
                x: extent.origin.x,
                y: extent.height - CGFloat(index + 1) * tileHeight,
                width: extent.width,
                height: tileHeight
            )

            debugLog(tag: debugTag, "extractColors tile index=\(index), cropRect=\(debugRect(cropRect))")

            return extractAverageColor(
                ciImage: ciImage,
                cropRect: cropRect,
                context: context,
                debugTag: debugTag,
                label: "extractColors tile index=\(index)"
            )
        }

        debugLog(tag: debugTag, "extractColors finished colorsCount=\(colors.count)")
        return colors
    }

    private static func extractAverageColor(
        ciImage: CIImage,
        cropRect: CGRect,
        context: CIContext = CIContext(),
        debugTag: String?,
        label: String
    ) -> UIColor? {
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = cropRect

        guard let outputImage = filter.outputImage else {
            debugLog(tag: debugTag, "\(label) failed because filter output is nil")
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

        debugLog(tag: debugTag, "\(label), rgba=\(debugRGBA(bytes))")

        return UIColor(
            red: CGFloat(bytes[0]) / 255,
            green: CGFloat(bytes[1]) / 255,
            blue: CGFloat(bytes[2]) / 255,
            alpha: CGFloat(bytes[3]) / 255
        )
    }

    private static func debugLog(tag: String?, _ message: @autoclosure () -> String) {
        guard let tag else { return }
        print("[DEBUG:\(tag)] \(message())")
    }

    private static func debugSize(_ size: CGSize) -> String {
        "w=\(debugNumber(size.width)), h=\(debugNumber(size.height))"
    }

    private static func debugRect(_ rect: CGRect) -> String {
        "x=\(debugNumber(rect.origin.x)), y=\(debugNumber(rect.origin.y)), w=\(debugNumber(rect.width)), h=\(debugNumber(rect.height))"
    }

    private static func debugNumber(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }

    private static func debugRGBA(_ bytes: [UInt8]) -> String {
        guard bytes.count >= 4 else {
            return "invalid"
        }

        return "\(bytes[0]),\(bytes[1]),\(bytes[2]),\(bytes[3])"
    }
}
