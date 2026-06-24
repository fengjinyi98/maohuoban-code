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
// - 确保 1415x1414 裁剪图不再生成 19MB PNG
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
        let hasAlpha = imageHasAlphaChannel(image)

        if hasAlpha {
            return encodePNG(image: image, fileName: baseName)
        }

        return encodeJPEG(
            image: image,
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
            pixelWidth: Int(image.size.width * image.scale),
            pixelHeight: Int(image.size.height * image.scale)
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
            pixelWidth: Int(image.size.width * image.scale),
            pixelHeight: Int(image.size.height * image.scale)
        )
    }

    // MARK: - 辅助

    /// 检测 UIImage 是否包含 alpha 通道
    private static func imageHasAlphaChannel(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else {
            return false
        }
        let alphaInfo = cgImage.alphaInfo
        return alphaInfo != .none && alphaInfo != .noneSkipFirst && alphaInfo != .noneSkipLast
    }

    private static func replaceExtension(of fileName: String, with ext: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        return "\(base).\(ext)"
    }

    private static func defaultFileName(for purpose: MHBMediaUploadPurpose) -> String {
        "\(purpose.usageKind).\(purpose.preferredFileExtension)"
    }
}
