import XCTest
@testable import maohuoban

// PetAlbumMenuActionTests 相册菜单动作测试
// 核心职责：
// - 固化相册长按菜单的动作顺序
// - 固化固定状态对应的菜单文案
final class PetAlbumMenuActionTests: XCTestCase {
    func testAlbumContextMenuActionsUseSystemAlbumOrderWhenAlbumIsNotPinned() {
        let actions = PetAlbumContextMenuActionResolver.actions(isPinned: false)

        XCTAssertEqual(
            actions,
            [.edit, .addPhotos, .playMemory, .deleteAlbum, .togglePin(isPinned: false)]
        )
    }

    func testAlbumContextMenuActionsUseUnpinTitleWhenAlbumIsPinned() {
        let action = PetAlbumContextMenuAction.togglePin(isPinned: true)

        XCTAssertEqual(action.title, "取消固定")
        XCTAssertEqual(action.systemImageName, "pin.slash")
    }

    func testPhotoContextMenuOnlyExposesDeleteForCurrentScope() {
        XCTAssertEqual(PetAlbumPhotoContextMenuActionResolver.actions(), [.deletePhoto])
    }
}
