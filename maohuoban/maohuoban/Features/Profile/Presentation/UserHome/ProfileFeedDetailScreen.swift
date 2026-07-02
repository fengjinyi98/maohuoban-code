import SwiftUI

// ProfileFeedDetailScreen 我的动态详情页
// 核心职责：
// - 根据帖子 ID 承载我的动态详情系统导航目标
// - 保持列表与详情共享同一互动状态源
struct ProfileFeedDetailScreen: View {
    let postID: String
    let currentUserStore: CurrentUserStore
    let interactionStore: FeedInteractionStore
    let onOpenTopicRoute: (ProfileRoute) -> Void

    var body: some View {
        if let detail = ProfileMockFeedDetail.detail(
            for: postID,
            authorName: currentUserStore.displayName,
            authorAvatarAssetName: currentUserStore.avatarAssetName
        ) {
            PetWorldFeedDetailLoadedScreen(
                detail: detail,
                currentUserIdentity: currentUserIdentity,
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
