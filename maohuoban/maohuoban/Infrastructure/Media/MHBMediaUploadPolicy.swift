import Foundation
import UIKit

// MHBMediaUploadPurpose 媒资上传用途
// 核心职责：
// - 映射 Rust MediaUploadUsage 的后端策略
// - 为编码器提供用途级参数选择
enum MHBMediaUploadPurpose: Equatable, Sendable {
    /// 用户 / 宠物头像
    case avatar
    /// 用户 / 宠物主页背景图
    case cover
    /// UGC / 相册图片
    case ugcImage
    /// 商品 / 服务图片
    case commodityImage
    /// 医疗 / 报告图片
    case medicalImage
    /// Live Photo 静态帧
    case livePhotoStill

    // MARK: 编码参数

    /// 默认 JPEG 压缩质量 0.0-1.0
    var defaultJPEGQuality: CGFloat {
        switch self {
        case .avatar: 0.90
        case .cover: 0.90
        case .ugcImage: 0.90
        case .commodityImage: 0.92
        case .medicalImage: 0.95
        case .livePhotoStill: 0.90
        }
    }

    /// 推荐文件扩展名（不含点号）
    var preferredFileExtension: String {
        switch self {
        case .avatar, .cover, .ugcImage, .commodityImage, .medicalImage, .livePhotoStill:
            "jpg"
        }
    }

    /// 用途标识字符串（对齐后端 usage_kind）
    var usageKind: String {
        switch self {
        case .avatar: "avatar"
        case .cover: "cover"
        case .ugcImage: "ugc.image"
        case .commodityImage: "commodity.image"
        case .medicalImage: "medical.image"
        case .livePhotoStill: "livephoto.still"
        }
    }
}
