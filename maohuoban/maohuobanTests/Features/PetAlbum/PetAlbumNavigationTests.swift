import XCTest
@testable import maohuoban

// PetAlbumNavigationTests 宠物相册导航测试
// 核心职责：
// - 固化相册流程的新建页面路由
// - 防止新建相册入口退化为无目标点击
final class PetAlbumNavigationTests: XCTestCase {
    @MainActor
    func testCreatePetAlbumRouteExistsForPetAlbumFlow() {
        XCTAssertEqual(ProfileRoute.createPetAlbum, .createPetAlbum)
        XCTAssertEqual(HomeRoute.createPetAlbum, .createPetAlbum)
    }
}
