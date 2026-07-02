import SwiftUI

// PetWorldFeedDetailScreen 宠物世界 Feed 详情页
// 核心职责：
// - 根据帖子 ID 承载 Feed 详情系统导航目标
// - 组合主图、正文、互动状态和评论树
struct PetWorldFeedDetailScreen<TopicRouteValue: Hashable>: View {
    let postID: String
    let currentUserStore: CurrentUserStore
    let interactionStore: FeedInteractionStore
    let topicRoute: (String) -> TopicRouteValue
    let onOpenTopicRoute: (TopicRouteValue) -> Void

    var body: some View {
        if let detail = PetWorldMockFeedDetail.detail(
            for: postID,
            currentUserName: currentUserStore.displayName
        ) {
            PetWorldFeedDetailLoadedScreen(
                detail: detail,
                currentUserIdentity: currentUserIdentity,
                interactionStore: interactionStore,
                topicRoute: topicRoute,
                onOpenTopicRoute: onOpenTopicRoute
            )
        } else {
            PetWorldFeedDetailMissingScreen()
        }
    }

    private var currentUserIdentity: FeedCommentAuthorIdentity {
        FeedCommentAuthorIdentity(
            userID: currentUserStore.userID ?? "current-user",
            userName: currentUserStore.displayName,
            userAvatarSource: currentUserStore.avatarSource,
            petID: nil,
            petName: nil,
            petAvatarAssetName: nil
        )
    }
}
