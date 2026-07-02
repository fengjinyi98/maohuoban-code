import Foundation

// FeedComment Feed 详情评论节点
// 核心职责：
// - 表达评论树中的父评论和子评论
// - 为评论树递归布局提供稳定身份和层级数据
nonisolated struct FeedComment: Identifiable, Equatable {
    let id: String
    let authorName: String
    let avatarAssetName: String
    let avatarSource: MHBAvatarSource?
    let text: String
    let publishedAt: Date
    let isPostAuthor: Bool
    let isOwnedByCurrentUser: Bool
    let isLiked: Bool
    let likeCount: Int
    let replies: [FeedComment]
    var petName: String?
    var petAvatarAssetName: String?

    nonisolated init(
        id: String,
        authorName: String,
        avatarAssetName: String,
        avatarSource: MHBAvatarSource? = nil,
        text: String,
        publishedAt: Date,
        isPostAuthor: Bool,
        isOwnedByCurrentUser: Bool,
        isLiked: Bool,
        likeCount: Int,
        replies: [FeedComment],
        petName: String? = nil,
        petAvatarAssetName: String? = nil
    ) {
        self.id = id
        self.authorName = authorName
        self.avatarAssetName = avatarAssetName
        self.avatarSource = avatarSource
        self.text = text
        self.publishedAt = publishedAt
        self.isPostAuthor = isPostAuthor
        self.isOwnedByCurrentUser = isOwnedByCurrentUser
        self.isLiked = isLiked
        self.likeCount = likeCount
        self.replies = replies
        self.petName = petName
        self.petAvatarAssetName = petAvatarAssetName
    }

    nonisolated var authorAvatarSubject: MHBAvatarSubject {
        let user = MHBAvatarUser(
            id: "\(id)-user",
            displayName: authorName,
            source: avatarSource ?? .asset(avatarAssetName),
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
