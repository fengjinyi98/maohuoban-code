import Foundation

// FeedComment Feed 详情评论节点
// 核心职责：
// - 表达评论树中的父评论和子评论
// - 为评论树递归布局提供稳定身份和层级数据
nonisolated struct FeedComment: Identifiable, Equatable {
    let id: String
    let authorName: String
    let avatarAssetName: String
    let text: String
    let publishedAt: Date
    let isPostAuthor: Bool
    let isOwnedByCurrentUser: Bool
    let isLiked: Bool
    let likeCount: Int
    let replies: [FeedComment]
    var petName: String? = nil
    var petAvatarAssetName: String? = nil

    nonisolated var authorAvatarSubject: MHBAvatarSubject {
        let user = MHBAvatarUser(
            id: "\(id)-user",
            displayName: authorName,
            source: .asset(avatarAssetName),
            sex: .unknown,
            sexVisibility: .hidden
        )

        guard let petAvatarAssetName else {
            return .user(user)
        }

        return .petWithUser(
            pet: MHBAvatarPet(
                id: "\(id)-pet",
                name: petName ?? "毛伙伴",
                source: .asset(petAvatarAssetName),
                species: .other,
                sex: .unknown
            ),
            user: user
        )
    }
}
