import XCTest
@testable import maohuoban

// FeedMoreMenuActionResolverTests Feed 更多菜单动作解析测试
// 核心职责：
// - 固化普通 Feed 和收藏夹 Feed 的更多菜单差异
// - 防止基础设施菜单内容被业务场景写死
@MainActor
final class FeedMoreMenuActionResolverTests: XCTestCase {
    func testDefaultFeedMoreMenuUsesDislikeAndReportActions() {
        XCTAssertEqual(FeedMoreMenuActionResolver.actions(context: .standard), [.dislike, .report])
    }

    func testFavoriteFolderFeedMoreMenuOnlyUsesRemoveFromFavoriteFolderAction() {
        XCTAssertEqual(
            FeedMoreMenuActionResolver.actions(context: .favoriteFolder),
            [.removeFromFavoriteFolder]
        )
    }
}
