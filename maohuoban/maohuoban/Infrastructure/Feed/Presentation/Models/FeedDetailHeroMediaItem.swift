import CoreGraphics
import Foundation

// FeedDetailHeroMediaItem Feed 详情头图媒体项
// 核心职责：
// - 描述详情页沉浸式画廊中的本地图片
// - 为轮播、分页指示和图片预览提供稳定身份
struct FeedDetailHeroMediaItem: Identifiable, Equatable {
    let id: String
    let assetName: String
    let pixelSize: CGSize?
}
