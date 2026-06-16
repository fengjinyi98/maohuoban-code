import AVFoundation
import UIKit

// MHBVideoFirstFrameExtractor 视频首帧提取工具
// 核心职责：
// - 从 Bundle 内置视频资源异步提取首帧图片
// - 为首页视频头图复用图片取色基础设施
// - 仅作为后端封面帧和主题色能力接入前的 mock、老数据和本地预览兜底
// 设计约束：
// - 正式上传链路应由后端从视频生成封面帧并提取主题色
// - 前端正式消费 API 返回的封面、视频和主题色字段，减少设备端首屏计算成本
enum MHBVideoFirstFrameExtractor {
    static func extract(
        resourceName: String,
        fileExtension: String = "mp4",
        maximumSize: CGSize = CGSize(width: 600, height: 600)
    ) async -> UIImage? {
        guard let url = MHBLocalMediaResource.url(
            resourceName: resourceName,
            fileExtension: fileExtension
        ) else {
            return nil
        }

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maximumSize
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.08, preferredTimescale: 600)

        return await withCheckedContinuation { continuation in
            generator.generateCGImageAsynchronously(
                for: CMTime(seconds: 0, preferredTimescale: 600)
            ) { image, _, _ in
                guard let image else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: UIImage(cgImage: image))
            }
        }
    }
}
