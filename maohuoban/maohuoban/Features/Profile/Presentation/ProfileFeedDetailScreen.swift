import SwiftUI

// ProfileFeedDetailScreen 我的动态详情页
// 核心职责：
// - 根据帖子 ID 承载我的动态详情系统导航目标
// - 保持列表与详情共享同一互动状态源
struct ProfileFeedDetailScreen: View {
    let postID: String
    let interactionStore: FeedInteractionStore
    let onOpenTopicRoute: (ProfileRoute) -> Void

    var body: some View {
        if let detail = ProfileMockFeedDetail.detail(for: postID) {
            PetWorldFeedDetailLoadedScreen(
                detail: detail,
                interactionStore: interactionStore,
                topicRoute: { topicName in
                    ProfileRoute.topicDetail(topicID: TopicIdentifier.id(for: topicName))
                },
                onOpenTopicRoute: onOpenTopicRoute
            )
        } else {
            PetWorldFeedDetailMissingScreen()
        }
    }
}
