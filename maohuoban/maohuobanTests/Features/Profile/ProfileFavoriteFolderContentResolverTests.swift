import XCTest
@testable import maohuoban

// ProfileFavoriteFolderContentResolverTests 我的收藏夹内容解析测试
// 核心职责：
// - 固化收藏夹内容按收藏顺序筛选 Feed 数据
// - 固化未知收藏夹返回空内容的兜底行为
final class ProfileFavoriteFolderContentResolverTests: XCTestCase {
    @MainActor
    func testFavoriteFolderReturnsFeedItemsInFolderOrder() {
        let folders = [
            ProfileFavoriteFolder(
                id: "pet-care",
                title: "新手养宠干货",
                itemCountText: "2 篇教程",
                coverImageAssetName: "HomePetAlbum4",
                isPrivate: false,
                postIDs: ["profile-health-note", "profile-morning-care"]
            )
        ]

        let items = ProfileFavoriteFolderContentResolver.feedItems(
            folderID: "pet-care",
            folders: folders,
            allItems: Self.feedItems
        )

        XCTAssertEqual(items.map(\.postID), ["profile-health-note", "profile-morning-care"])
    }

    @MainActor
    func testUnknownFavoriteFolderReturnsEmptyItems() {
        let items = ProfileFavoriteFolderContentResolver.feedItems(
            folderID: "missing",
            folders: [],
            allItems: Self.feedItems
        )

        XCTAssertTrue(items.isEmpty)
    }

    @MainActor
    private static var feedItems: [FeedItem] {
        ProfileMockFeed.cards(
            authorName: "测试用户",
            authorAvatarAssetName: "HomeUserAvatarMock"
        )
    }
}
