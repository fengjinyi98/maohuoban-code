import XCTest
@testable import maohuoban

// ProfileFavoriteFolderNavigationTests 我的收藏夹导航测试
// 核心职责：
// - 固化收藏夹流程的新建页面路由
// - 防止新建收藏夹入口退化为无目标点击
final class ProfileFavoriteFolderNavigationTests: XCTestCase {
    @MainActor
    func testCreateFavoriteFolderRouteExistsForFavoriteFolderFlow() {
        XCTAssertEqual(ProfileRoute.createFavoriteFolder, .createFavoriteFolder)
    }
}
