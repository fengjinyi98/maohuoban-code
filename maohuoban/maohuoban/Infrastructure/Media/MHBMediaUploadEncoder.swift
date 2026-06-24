import Foundation
import UIKit

// MHBMediaUploadEncodeResult 编码结果
// 核心职责：
// - 携带编码后的图片数据和元信息
// - 供调用方直接构建 multipart 上传草稿
struct MHBMediaUploadEncodeResult: Equatable, Sendable {
    /// 编码后的文件数据
    let data: Data
    /// MIME 类型（如 "image/jpeg"）
    let mimeType: String
    /// 建议文件名（含扩展名）
    let fileName: String
    /// 实际使用的 JPEG 质量（仅 JPEG 编码有效，PNG 为 1.0）
    let quality: CGFloat
    /// 输出像素宽度
    let pixelWidth: Int
    /// 输出像素高度
    let pixelHeight: Int
}

// MHBMediaUploadEncoder 媒资上传统一编码器
// 核心职责：
// - 根据用途选择 JPEG / PNG 编码策略
// - 照片类默认 JPEG，透明图 / 贴纸保 PNG
// - 按用途约束源图最长边，避免头像等照片类生成超大 PNG
enum MHBMediaUploadEncoder {

    // MARK: - 公共入口

    /// 从 UIImage 编码上传文件
    /// - Parameters:
    ///   - image: 源图片（已裁剪/方向修正后）
    ///   - purpose: 上传用途
    ///   - fileName: 建议文件名（不含扩展名），传 nil 则自动生成
    /// - Returns: 编码结果，包含 data / mime / fileName / quality / pixels
    static func encode(
        image: UIImage,
        purpose: MHBMediaUploadPurpose,
        fileName: String? = nil
    ) -> MHBMediaUploadEncodeResult? {
        let baseName = fileName ?? defaultFileName(for: purpose)
        let shouldPreserveAlpha = purpose.preservesAlphaWhenPresent && imageHasAlphaChannel(image)
        let preparedImage = preparedImageForEncoding(
            image,
            purpose: purpose,
            preservingAlpha: shouldPreserveAlpha
        )

        if shouldPreserveAlpha {
            return encodePNG(image: preparedImage, fileName: baseName)
        }

        return encodeJPEG(
            image: preparedImage,
            fileName: baseName,
            quality: purpose.defaultJPEGQuality
        )
    }

    // MARK: - 编码实现

    private static func encodeJPEG(
        image: UIImage,
        fileName: String,
        quality: CGFloat
    ) -> MHBMediaUploadEncodeResult? {
        guard let data = image.jpegData(compressionQuality: quality) else {
            return nil
        }
        let safeFileName = replaceExtension(of: fileName, with: "jpg")
        return MHBMediaUploadEncodeResult(
            data: data,
            mimeType: "image/jpeg",
            fileName: safeFileName,
            quality: quality,
            pixelWidth: Int(pixelSize(of: image).width),
            pixelHeight: Int(pixelSize(of: image).height)
        )
    }

    private static func encodePNG(
        image: UIImage,
        fileName: String
    ) -> MHBMediaUploadEncodeResult? {
        guard let data = image.pngData() else {
            return nil
        }
        let safeFileName = replaceExtension(of: fileName, with: "png")
        return MHBMediaUploadEncodeResult(
            data: data,
            mimeType: "image/png",
            fileName: safeFileName,
            quality: 1.0,
            pixelWidth: Int(pixelSize(of: image).width),
            pixelHeight: Int(pixelSize(of: image).height)
        )
    }

    // MARK: - 辅助

    /// 按用途策略准备编码前图片
    private static func preparedImageForEncoding(
        _ image: UIImage,
        purpose: MHBMediaUploadPurpose,
        preservingAlpha: Bool
    ) -> UIImage {
        let sourcePixelSize = pixelSize(of: image)
        guard sourcePixelSize.width > 0, sourcePixelSize.height > 0 else {
            return image
        }

        let longEdge = max(sourcePixelSize.width, sourcePixelSize.height)
        let scaleFactor = min(1, purpose.maxLongEdgePixels / longEdge)
        let targetPixelSize = CGSize(
            width: max(1, (sourcePixelSize.width * scaleFactor).rounded()),
            height: max(1, (sourcePixelSize.height * scaleFactor).rounded())
        )
        let needsOpaqueRedraw = !preservingAlpha && imageHasAlphaChannel(image)
        let needsResize = targetPixelSize != sourcePixelSize

        guard needsResize || needsOpaqueRedraw else {
            return image
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !preservingAlpha
        return UIGraphicsImageRenderer(size: targetPixelSize, format: format).image { context in
            if !preservingAlpha {
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: targetPixelSize))
            }
            image.draw(in: CGRect(origin: .zero, size: targetPixelSize))
        }
    }

    /// 检测 UIImage 是否包含 alpha 通道
    private static func imageHasAlphaChannel(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else {
            return false
        }
        let alphaInfo = cgImage.alphaInfo
        return alphaInfo != .none && alphaInfo != .noneSkipFirst && alphaInfo != .noneSkipLast
    }

    /// 读取 UIImage 实际像素尺寸
    private static func pixelSize(of image: UIImage) -> CGSize {
        if let cgImage = image.cgImage {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        return CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
    }

    private static func replaceExtension(of fileName: String, with ext: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        return "\(base).\(ext)"
    }

    private static func defaultFileName(for purpose: MHBMediaUploadPurpose) -> String {
        "\(purpose.usageKind).\(purpose.preferredFileExtension)"
    }
}
