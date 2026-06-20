import SwiftUI

// PetWorldFeedDetailScreen 宠物世界 Feed 详情页
// 核心职责：
// - 根据帖子 ID 承载 Feed 详情系统导航目标
// - 组合主图、正文、互动状态和评论树
struct PetWorldFeedDetailScreen<TopicRouteValue: Hashable>: View {
    let postID: String
    let interactionStore: FeedInteractionStore
    let topicRoute: (String) -> TopicRouteValue
    let onOpenTopicRoute: (TopicRouteValue) -> Void

    var body: some View {
        if let detail = PetWorldMockFeedDetail.detail(for: postID) {
            PetWorldFeedDetailLoadedScreen(
                detail: detail,
                interactionStore: interactionStore,
                topicRoute: topicRoute,
                onOpenTopicRoute: onOpenTopicRoute
            )
        } else {
            PetWorldFeedDetailMissingScreen()
        }
    }
}
