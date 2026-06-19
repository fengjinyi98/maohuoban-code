import Foundation

// PetWorldFeedInteractionState Feed 卡片互动状态
// 核心职责：
// - 表达单张 Feed 卡片的点赞状态和计数
// - 作为列表页与详情页共享互动状态的展示快照
struct PetWorldFeedInteractionState: Equatable {
    let isLiked: Bool
    let likeCount: Int
}
