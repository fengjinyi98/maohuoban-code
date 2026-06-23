import Foundation

// FeedItem UGC Feed 卡片展示模型
// 核心职责：
// - 描述用户发布内容卡片渲染所需的最小字段
// - 为快速 UI 阶段的 mock 数据提供稳定身份
nonisolated struct FeedItem: Identifiable, Equatable {
    let postID: String
    let petName: String?
    let petAvatarAssetName: String?
    let recommendationReason: FeedRecommendationReason
    let text: String
    let authorAvatarAssetName: String
    let authorName: String
    let publishedAt: Date
    let mediaAssetName: String
    let isLiked: Bool
    let likeCount: Int
    let repostCount: Int
    let commentCount: Int

    var id: String {
        postID
    }

    nonisolated var authorAvatarSubject: MHBAvatarSubject {
        let user = MHBAvatarUser(
            id: "\(postID)-user",
            displayName: authorName,
            source: .asset(authorAvatarAssetName),
            sex: .unknown,
            sexVisibility: .hidden
        )

        guard let petAvatarAssetName else {
            return .user(user)
        }

        return .petWithUser(
            pet: MHBAvatarPet(
                id: "\(postID)-pet",
                name: petName ?? "毛伙伴",
                source: .asset(petAvatarAssetName),
                species: .other,
                sex: .unknown
            ),
            user: user
        )
    }
}
