import Foundation

// PetBackgroundMediaKind 宠物背景媒体类型
// 核心职责：
// - 区分背景图片和背景视频
// - 与后端宠物档案 DTO 保持稳定映射
enum PetBackgroundMediaKind: String, Codable, Equatable {
    case image
    case video
    case livePhoto = "live_photo"
}

// PetMediaUsageKind 宠物媒体用途
// 核心职责：
// - 固定媒体资产业务用途
// - 支持头像和背景媒体复用上传响应模型
enum PetMediaUsageKind: String, Codable, Equatable {
    case avatar = "pet.avatar"
    case backgroundImage = "pet.background.image"
    case backgroundVideo = "pet.background.video"
    case backgroundLivePhoto = "pet.background.live_photo"
    case albumPhoto = "pet.album.photo"
    case foodInventoryCover = "pet.food_inventory.cover"
    case eventAttachment = "pet.event.attachment"
}

// PetMediaAssetComponentKind 组合媒体组件类型
// 核心职责：
// - 固定 Live Photo 两个组件的后端枚举
// - 避免展示层用字符串判断组件语义
enum PetMediaAssetComponentKind: String, Codable, Equatable {
    case still
    case pairedVideo = "paired_video"
}

// PetMediaDerivativeKind 宠物媒体派生类型
// 核心职责：
// - 区分缩略图、视频封面帧和主题色派生
// - 与后端 media_derivatives.derivative_kind 保持稳定映射
enum PetMediaDerivativeKind: String, Codable, Equatable {
    case thumbnail
    case videoCoverFrame = "video_cover_frame"
    case themeColorFrame = "theme_color_frame"
}

// PetMediaAssetStatus 宠物媒体资产状态
// 核心职责：
// - 表达媒体资产生命周期
// - 与后端清理状态保持一致
enum PetMediaAssetStatus: String, Codable, Equatable {
    case uploaded
    case bound
    case cleanupPending = "cleanup_pending"
    case deleted
    case failed
}

// PetMediaBindingStatus 宠物媒体绑定状态
// 核心职责：
// - 表达媒体绑定当前有效性
// - 支持替换后追溯旧绑定
enum PetMediaBindingStatus: String, Codable, Equatable {
    case active
    case replaced
    case deleted
}
