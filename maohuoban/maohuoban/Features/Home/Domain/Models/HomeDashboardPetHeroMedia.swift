import Foundation

extension HomeDashboardSnapshot.PetHeroSummary {
    // HeroMedia 首页头图媒体来源
    // 核心职责：
    // - 表达宠物头图当前使用图片或视频
    // - 为渲染层和主题取色提供统一媒体入口
    enum HeroMedia: Equatable {
        case image(assetName: String)
        case remoteImage(urlString: String, fallbackAssetName: String)
        case video(resourceName: String, fileExtension: String, fallbackImageAssetName: String?)
        case remoteVideo(urlString: String, fallbackImageURLString: String?, fallbackImageAssetName: String?)
        case remoteLivePhoto(
            stillURLString: String,
            pairedVideoURLString: String,
            cropMetadata: MHBImageCropMetadata?,
            fallbackImageAssetName: String?
        )
    }
}
