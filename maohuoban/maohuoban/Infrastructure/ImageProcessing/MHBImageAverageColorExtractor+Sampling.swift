import CoreImage.CIFilterBuiltins
import UIKit

extension MHBImageAverageColorExtractor {
    static func downsample(image: UIImage, maxDimension: CGFloat) -> UIImage {
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

    static func extractColors(image: UIImage, count: Int) -> [UIColor] {
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

    static func extractAverageColor(
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

    static func averageRGBBrightness(of color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red + green + blue) / 3
    }
}
