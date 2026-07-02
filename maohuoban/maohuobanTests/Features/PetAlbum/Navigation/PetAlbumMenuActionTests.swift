import XCTest
@testable import maohuoban

// PetAlbumMenuActionTests 相册菜单动作测试
// 核心职责：
// - 固化相册长按菜单的动作顺序
// - 固化固定状态对应的菜单文案
// - 固化相册详情页工具栏菜单动作顺序
final class PetAlbumMenuActionTests: XCTestCase {
    func testAlbumContextMenuActionsUseSystemAlbumOrderWhenAlbumIsNotPinned() {
        let actions = PetAlbumContextMenuActionResolver.actions(isPinned: false)

        XCTAssertEqual(
            actions,
            [.edit, .addPhotos, .shareAlbum, .deleteAlbum, .togglePin(isPinned: false)]
        )
    }

    func testAlbumContextMenuShareActionUsesShareCopy() {
        let action = PetAlbumContextMenuAction.shareAlbum

        XCTAssertEqual(action.title, "分享相册")
        XCTAssertEqual(action.systemImageName, "square.and.arrow.up")
    }

    func testAlbumContextMenuActionsUseUnpinTitleWhenAlbumIsPinned() {
        let action = PetAlbumContextMenuAction.togglePin(isPinned: true)

        XCTAssertEqual(action.title, "取消固定")
        XCTAssertEqual(action.systemImageName, "pin.slash")
    }

    func testAlbumContextMenuEditActionUsesTitleAndCoverCopy() {
        let action = PetAlbumContextMenuAction.edit

        XCTAssertEqual(action.title, "编辑标题和封面")
        XCTAssertEqual(action.systemImageName, "pencil")
    }

    func testPhotoContextMenuOnlyExposesDeleteForCurrentScope() {
        XCTAssertEqual(PetAlbumPhotoContextMenuActionResolver.actions(), [.deletePhoto])
    }

    func testAlbumDetailToolbarMenuActionsUseUploadThenShareOrder() {
        let actions = PetAlbumDetailToolbarMenuActionResolver.actions()

        XCTAssertEqual(actions, [.uploadPhotos, .shareAlbum])
        XCTAssertEqual(actions.map(\.title), ["上传照片", "分享相册"])
        XCTAssertEqual(actions.map(\.systemImageName), ["photo.badge.plus", "square.and.arrow.up"])
    }
}
