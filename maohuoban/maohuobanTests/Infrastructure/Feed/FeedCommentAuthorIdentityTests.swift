import XCTest
@testable import maohuoban

// FeedCommentAuthorIdentityTests 评论作者身份测试
// 核心职责：
// - 固化当前用户有宠物时新评论携带人宠融合头像字段
// - 防止评论发送路径回退为只展示用户头像
final class FeedCommentAuthorIdentityTests: XCTestCase {
    func testMakeCommentKeepsCompositeAvatarWhenAuthorHasPet() {
        let identity = FeedCommentAuthorIdentity(
            userID: "user-1",
            userName: "小满",
            userAvatarAssetName: "HomeUserAvatarMock",
            petID: "pet-1",
            petName: "奶油",
            petAvatarAssetName: "HomePetHeroMock"
        )

        let comment = identity.makeComment(
            id: "comment-1",
            text: "太可爱了",
            publishedAt: Date(timeIntervalSince1970: 0),
            isPostAuthor: true,
            isOwnedByCurrentUser: true
        )

        XCTAssertEqual(comment.petName, "奶油")
        XCTAssertEqual(comment.petAvatarAssetName, "HomePetHeroMock")
        XCTAssertEqual(
            comment.authorAvatarSubject,
            .petWithUser(
                pet: MHBAvatarPet(
                    id: "comment-1-pet",
                    name: "奶油",
                    source: .asset("HomePetHeroMock"),
                    species: .other,
                    sex: .unknown
                ),
                user: MHBAvatarUser(
                    id: "comment-1-user",
                    displayName: "小满",
                    source: .asset("HomeUserAvatarMock"),
                    sex: .unknown,
                    sexVisibility: .hidden
                )
            )
        )
    }

    func testMakeCommentFallsBackToUserAvatarWhenAuthorHasNoPet() {
        let identity = FeedCommentAuthorIdentity(
            userID: "user-1",
            userName: "游客",
            userAvatarAssetName: "HomeUserAvatarMock",
            petID: nil,
            petName: nil,
            petAvatarAssetName: nil
        )

        let comment = identity.makeComment(
            id: "comment-1",
            text: "想了解一下",
            publishedAt: Date(timeIntervalSince1970: 0),
            isPostAuthor: false,
            isOwnedByCurrentUser: true
        )

        XCTAssertNil(comment.petName)
        XCTAssertNil(comment.petAvatarAssetName)
        XCTAssertEqual(
            comment.authorAvatarSubject,
            .user(
                MHBAvatarUser(
                    id: "comment-1-user",
                    displayName: "游客",
                    source: .asset("HomeUserAvatarMock"),
                    sex: .unknown,
                    sexVisibility: .hidden
                )
            )
        )
    }
}
