import XCTest
@testable import maohuoban

// FeedAvatarSubjectTests Feed 头像主体测试
// 核心职责：
// - 固化 Feed 作者和评论作者的人宠融合头像映射
// - 防止后续回退到只显示用户或只显示宠物头像
final class FeedAvatarSubjectTests: XCTestCase {
    func testFeedItemUsesCompositeAvatarWhenAuthorHasPetAvatar() {
        let item = makeFeedItem(
            petName: "糯米",
            petAvatarAssetName: "HomePetAlbum1",
            authorAvatarAssetName: "HomePartnerAvatar"
        )

        XCTAssertEqual(
            item.authorAvatarSubject,
            .petWithUser(
                pet: MHBAvatarPet(
                    id: "feed-post-1-pet",
                    name: "糯米",
                    source: .asset("HomePetAlbum1"),
                    species: .other,
                    sex: .unknown
                ),
                user: MHBAvatarUser(
                    id: "feed-post-1-user",
                    displayName: "林一",
                    source: .asset("HomePartnerAvatar"),
                    sex: .unknown,
                    sexVisibility: .hidden
                )
            )
        )
    }

    func testFeedItemUsesUserAvatarWhenAuthorHasNoPetAvatar() {
        let item = makeFeedItem(
            petName: nil,
            petAvatarAssetName: nil,
            authorAvatarAssetName: "HomePartnerAvatar"
        )

        XCTAssertEqual(
            item.authorAvatarSubject,
            .user(
                MHBAvatarUser(
                    id: "feed-post-1-user",
                    displayName: "林一",
                    source: .asset("HomePartnerAvatar"),
                    sex: .unknown,
                    sexVisibility: .hidden
                )
            )
        )
    }

    func testFeedCommentUsesCompositeAvatarWhenCommenterHasPetAvatar() {
        let comment = FeedComment(
            id: "comment-1",
            authorName: "小满妈妈",
            avatarAssetName: "HomePartnerAvatar",
            text: "太可爱了",
            publishedAt: Date(timeIntervalSince1970: 0),
            isPostAuthor: false,
            isOwnedByCurrentUser: false,
            isLiked: false,
            likeCount: 0,
            replies: [],
            petName: "小满",
            petAvatarAssetName: "HomePetAlbum2"
        )

        XCTAssertEqual(
            comment.authorAvatarSubject,
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
                    displayName: "小满妈妈",
                    source: .asset("HomePartnerAvatar"),
                    sex: .unknown,
                    sexVisibility: .hidden
                )
            )
        )
    }

    func testFeedCommentUsesUserAvatarWhenCommenterHasNoPetAvatar() {
        let comment = FeedComment(
            id: "comment-1",
            authorName: "路人甲",
            avatarAssetName: "HomePartnerAvatar",
            text: "太可爱了",
            publishedAt: Date(timeIntervalSince1970: 0),
            isPostAuthor: false,
            isOwnedByCurrentUser: false,
            isLiked: false,
            likeCount: 0,
            replies: []
        )

        XCTAssertEqual(
            comment.authorAvatarSubject,
            .user(
                MHBAvatarUser(
                    id: "comment-1-user",
                    displayName: "路人甲",
                    source: .asset("HomePartnerAvatar"),
                    sex: .unknown,
                    sexVisibility: .hidden
                )
            )
        )
    }

    private func makeFeedItem(
        petName: String?,
        petAvatarAssetName: String?,
        authorAvatarAssetName: String
    ) -> FeedItem {
        FeedItem(
            postID: "feed-post-1",
            petName: petName,
            petAvatarAssetName: petAvatarAssetName,
            recommendationReason: .qualityContent("测试推荐"),
            text: "今天一起去公园",
            authorAvatarAssetName: authorAvatarAssetName,
            authorName: "林一",
            publishedAt: Date(timeIntervalSince1970: 0),
            mediaAssetName: "HomeGalleryAlbum1",
            isLiked: false,
            likeCount: 0,
            repostCount: 0,
            commentCount: 0
        )
    }
}
