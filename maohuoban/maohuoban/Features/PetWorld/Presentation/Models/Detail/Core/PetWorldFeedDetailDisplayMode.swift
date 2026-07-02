import Foundation

// PetWorldFeedDetailDisplayMode 帖子详情展示模式
// 核心职责：
// - 区分画廊详情页与图文混排详情页
// - 为详情页渲染分支提供稳定枚举值
enum PetWorldFeedDetailDisplayMode: Equatable {
    case gallery
    case interleaved
}
