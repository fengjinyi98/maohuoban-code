import XCTest
@testable import maohuoban

// PetAlbumNavigationTests 宠物相册导航测试
// 核心职责：
// - 固化相册流程的新建页面路由
// - 固化相册流程的编辑页面路由
// - 防止新建相册入口退化为无目标点击
final class PetAlbumNavigationTests: XCTestCase {
    @MainActor
    func testCreatePetAlbumRouteExistsForPetAlbumFlow() {
        XCTAssertEqual(ProfileRoute.createPetAlbum, .createPetAlbum)
        XCTAssertEqual(HomeRoute.createPetAlbum, .createPetAlbum)
    }

    @MainActor
    func testEditPetAlbumRouteCarriesEditContextForPetAlbumFlow() {
        let context = PetAlbumEditContext(
            albumID: "album-1",
            initialName: "糯米成长",
            initialCoverImageAssetName: "HomeGalleryAlbum1",
            initialIsPrivate: true
        )

        XCTAssertEqual(ProfileRoute.editPetAlbum(context), .editPetAlbum(context))
        XCTAssertEqual(HomeRoute.editPetAlbum(context), .editPetAlbum(context))
    }
}
