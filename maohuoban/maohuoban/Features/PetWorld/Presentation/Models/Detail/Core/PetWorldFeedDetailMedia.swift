import CoreGraphics
import Foundation

// PetWorldFeedDetailMedia 宠物世界详情媒体模型
// 核心职责：
// - 描述详情页轮播图中的单个媒体项
// - 为 SwiftUI 轮播和指示器提供稳定身份
struct PetWorldFeedDetailMedia: Identifiable, Equatable {
    let id: String
    let assetName: String
    let pixelSize: CGSize?
}
