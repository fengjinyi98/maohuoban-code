import XCTest
@testable import maohuoban

// FeedInteractionStoreAvatarTests Feed 评论头像状态测试
// 核心职责：
// - 固化评论互动重建节点时保留人宠融合头像字段
// - 防止点赞、回复等操作把评论头像回退成用户头像
final class FeedInteractionStoreAvatarTests: XCTestCase {
    @MainActor
    func testToggleCommentLikeKeepsCommentCompositeAvatarSubject() {
        let store = FeedInteractionStore(cards: [])
        let comment = makeComment(
            id: "comment-1",
            petName: "小满",
            petAvatarAssetName: "HomePetAlbum2"
        )
        store.prepareCommentsIfNeeded(postID: "post-1", comments: [comment])

        store.toggleCommentLike(postID: "post-1", commentID: "comment-1")

        let updatedComment = store.comments(postID: "post-1", fallbackComments: [])[0]
        XCTAssertEqual(updatedComment.isLiked, true)
        XCTAssertEqual(
            updatedComment.authorAvatarSubject,
            .petWithUser(
                pet: MHBAvatarPet(
                    id: "comment-1-pet",
                    name: "小满",
                    source: .asset("HomePetAlbum2"),
                    species: .other,
                    sex: .unknown
                ),
                user: MHBAvatarUser(
                    id: "comment-1-user",
                    displayName: "林一",
                    source: .asset("HomeUserAvatarMock"),
                    sex: .unknown,
                    sexVisibility: .hidden
                )
            )
        )
    }

    @MainActor
    func testAddingReplyKeepsParentCompositeAvatarSubject() {
        let store = FeedInteractionStore(cards: [])
        let parentComment = makeComment(
            id: "comment-1",
            petName: "小满",
            petAvatarAssetName: "HomePetAlbum2"
        )
        let reply = makeComment(
            id: "reply-1",
            petName: "奶盖",
            petAvatarAssetName: "HomePetAlbum3"
        )
        store.prepareCommentsIfNeeded(postID: "post-1", comments: [parentComment])

        store.addComment(
            postID: "post-1",
            parentCommentID: "comment-1",
            comment: reply
        )

        let updatedParent = store.comments(postID: "post-1", fallbackComments: [])[0]
        XCTAssertEqual(updatedParent.replies.count, 1)
        XCTAssertEqual(updatedParent.petName, "小满")
        XCTAssertEqual(updatedParent.petAvatarAssetName, "HomePetAlbum2")
        XCTAssertEqual(
            updatedParent.authorAvatarSubject,
            .petWithUser(
                pet: MHBAvatarPet(
                    id: "comment-1-pet",
                    name: "小满",
                    source: .asset("HomePetAlbum2"),
                    species: .other,
                    sex: .unknown
                ),
                user: MHBAvatarUser(
                    id: "comment-1-user",
                    displayName: "林一",
                    source: .asset("HomeUserAvatarMock"),
                    sex: .unknown,
                    sexVisibility: .hidden
                )
            )
        )
    }

    private func makeComment(
        id: String,
        petName: String?,
        petAvatarAssetName: String?
    ) -> FeedComment {
        FeedComment(
            id: id,
            authorName: "林一",
            avatarAssetName: "HomeUserAvatarMock",
            text: "好可爱",
            publishedAt: Date(timeIntervalSince1970: 0),
            isPostAuthor: false,
            isOwnedByCurrentUser: false,
            isLiked: false,
            likeCount: 0,
            replies: [],
            petName: petName,
            petAvatarAssetName: petAvatarAssetName
        )
    }
}
