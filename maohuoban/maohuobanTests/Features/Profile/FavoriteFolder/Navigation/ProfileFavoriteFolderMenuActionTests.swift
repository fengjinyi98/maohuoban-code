import XCTest
@testable import maohuoban

// ProfileFavoriteFolderMenuActionTests 收藏夹菜单动作测试
// 核心职责：
// - 固化收藏夹长按菜单的动作顺序
// - 固化固定状态对应的菜单文案
final class ProfileFavoriteFolderMenuActionTests: XCTestCase {
    func testFavoriteFolderContextMenuActionsUseProductOrderWhenFolderIsNotPinned() {
        let actions = ProfileFavoriteFolderContextMenuActionResolver.actions(isPinned: false)

        XCTAssertEqual(
            actions,
            [.editNameAndPrivacy, .togglePin(isPinned: false), .share, .delete]
        )
    }

    func testFavoriteFolderContextMenuEditActionUsesNameAndPrivacyCopy() {
        let action = ProfileFavoriteFolderContextMenuAction.editNameAndPrivacy

        XCTAssertEqual(action.title, "编辑名字和隐私")
        XCTAssertEqual(action.systemImageName, "pencil")
    }

    func testFavoriteFolderContextMenuActionsUseUnpinTitleWhenFolderIsPinned() {
        let action = ProfileFavoriteFolderContextMenuAction.togglePin(isPinned: true)

        XCTAssertEqual(action.title, "取消固定")
        XCTAssertEqual(action.systemImageName, "pin.slash")
    }
}
