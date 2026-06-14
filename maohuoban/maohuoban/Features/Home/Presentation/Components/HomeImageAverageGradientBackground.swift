import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import MaohuobanDesignSystem

// HomeImageAverageGradientBackground 首页图片平均色背景
// 核心职责：
// - 从首页头图资源中提取纵向分段平均色
// - 为首页滚动背景提供与头图一致的渐变氛围
struct HomeImageAverageGradientBackground: View {
    let assetName: String?
    let colorCount: Int
    let animation: Animation?
    let blurRadius: CGFloat

    @State private var colors: [Color] = []

    init(
        assetName: String?,
        colorCount: Int = 4,
        animation: Animation? = .smooth,
        blurRadius: CGFloat = 34
    ) {
        self.assetName = assetName
        self.colorCount = colorCount
        self.animation = animation
        self.blurRadius = blurRadius
    }

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color

            if let assetName {
                HomeBlurredImageBackground(
                    assetName: assetName,
                    blurRadius: blurRadius
                )
            }

            LinearGradient(
                colors: gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.42)

            MHBTheme.ColorToken.background.color
                .opacity(0.22)
        }
        .onAppear {
            updateColors(for: assetName)
        }
        .onChange(of: assetName) { _, newValue in
            updateColors(for: newValue)
        }
    }

    private var gradientColors: [Color] {
        guard colors.isEmpty == false else {
            return [
                MHBTheme.ColorToken.background.color,
                MHBTheme.ColorToken.background.color
            ]
        }

        return colors
    }

    private func updateColors(for assetName: String?) {
        guard
            let assetName,
            let image = UIImage(named: assetName)
        else {
            colors = []
            return
        }

        let nextColors = Self.extractColors(
            image: Self.downsize(image: image),
            count: colorCount
        )

        guard nextColors.isEmpty == false else {
            colors = []
            return
        }

        if let animation, colors.isEmpty == false {
            withAnimation(animation) {
                colors = nextColors
            }
        } else {
            colors = nextColors
        }
    }

    private nonisolated static func downsize(image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 200
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

        return UIGraphicsImageRenderer(size: newSize, format: renderFormat).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private nonisolated static func extractColors(image: UIImage, count: Int) -> [Color] {
        guard
            count > 0,
            let ciImage = CIImage(image: image)
        else {
            return []
        }

        let extent = ciImage.extent
        let tileHeight = extent.height / CGFloat(count)
        let context = CIContext()

        return (0..<count).compactMap { index in
            let cropRect = CGRect(
                x: extent.origin.x,
                y: extent.height - CGFloat(index + 1) * tileHeight,
                width: extent.width,
                height: tileHeight
            )

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

            return Color(
                red: CGFloat(bytes[0]) / 255,
                green: CGFloat(bytes[1]) / 255,
                blue: CGFloat(bytes[2]) / 255,
                opacity: CGFloat(bytes[3]) / 255
            )
        }
    }
}

// HomeBlurredImageBackground 首页模糊图片背景
// 核心职责：
// - 将当前头图作为页面背景的模糊底图
// - 通过放大裁切隐藏模糊边缘
private struct HomeBlurredImageBackground: View {
    let assetName: String
    let blurRadius: CGFloat

    var body: some View {
        GeometryReader { geometry in
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(1.12)
                .blur(radius: blurRadius, opaque: true)
                .saturation(1.08)
                .opacity(0.78)
                .clipped()
        }
        .clipped()
    }
}
