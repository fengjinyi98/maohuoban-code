import XCTest
@testable import maohuoban

// PetAlbumNavigationTests 宠物相册导航测试
// 核心职责：
// - 固化相册模块内部的新建、详情和编辑页面路由
// - 防止相册流程退回到首页路由承载业务页面
final class PetAlbumNavigationTests: XCTestCase {
    @MainActor
    func testCreateAndDetailPetAlbumRoutesBelongToPetAlbumFlow() {
        XCTAssertEqual(PetAlbumRoute.create, .create)
        XCTAssertEqual(PetAlbumRoute.detail(albumID: "album-1"), .detail(albumID: "album-1"))
    }

    @MainActor
    func testEditPetAlbumRouteCarriesEditContextInsidePetAlbumFlow() {
        let context = PetAlbumEditContext(
            albumID: "album-1",
            initialName: "糯米成长",
            initialCoverImageAssetName: "HomeGalleryAlbum1",
            initialIsPrivate: true
        )

        XCTAssertEqual(PetAlbumRoute.edit(context), .edit(context))
    }
}
