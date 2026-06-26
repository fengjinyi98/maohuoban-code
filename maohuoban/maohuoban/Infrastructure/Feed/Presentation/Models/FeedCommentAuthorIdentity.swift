import Foundation

// FeedCommentAuthorIdentity 评论作者身份
// 核心职责：
// - 统一描述评论发送者的用户头像和可选宠物头像
// - 在创建评论节点时保留人宠融合头像所需字段
// - 消费 MHBAvatarSource 以支持远端头像地址
nonisolated struct FeedCommentAuthorIdentity: Equatable {
    let userID: String
    let userName: String
    let userAvatarSource: MHBAvatarSource
    let petID: String?
    let petName: String?
    let petAvatarAssetName: String?

    nonisolated var avatarSubject: MHBAvatarSubject {
        let user = MHBAvatarUser(
            id: userID,
            displayName: userName,
            source: userAvatarSource,
            sex: .unknown,
            sexVisibility: .hidden
        )

        guard let petAvatarAssetName else {
            return .user(user)
        }

        return .petWithUser(
            pet: MHBAvatarPet(
                id: petID ?? "\(userID)-pet",
                name: petName ?? "毛伙伴",
                source: .asset(petAvatarAssetName),
                species: .other,
                sex: .unknown
            ),
            user: user
        )
    }

    nonisolated func makeComment(
        id: String,
        text: String,
        publishedAt: Date,
        isPostAuthor: Bool,
        isOwnedByCurrentUser: Bool
    ) -> FeedComment {
        FeedComment(
            id: id,
            authorName: userName,
            avatarAssetName: assetNameFromSource,
            avatarSource: userAvatarSource,
            text: text,
            publishedAt: publishedAt,
            isPostAuthor: isPostAuthor,
            isOwnedByCurrentUser: isOwnedByCurrentUser,
            isLiked: false,
            likeCount: 0,
            replies: [],
            petName: petAvatarAssetName == nil ? nil : petName,
            petAvatarAssetName: petAvatarAssetName
        )
    }

    private var assetNameFromSource: String {
        switch userAvatarSource {
        case .asset(let name):
            name
        default:
            ""
        }
    }
}
