import XCTest
@testable import maohuoban

// FeedMoreMenuPresentationStateTests Feed 更多菜单展示状态测试
// 核心职责：
// - 固化更多按钮点击后的展开和收起规则
// - 保持同城 Feed 与宠物世界 Feed 使用一致的菜单状态语义
@MainActor
final class FeedMoreMenuPresentationStateTests: XCTestCase {
    func testTogglePresentsPostWhenNoMenuIsShown() {
        let presentedPostID = FeedMoreMenuPresentationStateResolver.toggledPostID(
            current: nil,
            postID: "post-1"
        )

        XCTAssertEqual(presentedPostID, "post-1")
    }

    func testToggleDismissesMenuForCurrentPost() {
        let presentedPostID = FeedMoreMenuPresentationStateResolver.toggledPostID(
            current: "post-1",
            postID: "post-1"
        )

        XCTAssertNil(presentedPostID)
    }

    func testToggleSwitchesMenuToAnotherPost() {
        let presentedPostID = FeedMoreMenuPresentationStateResolver.toggledPostID(
            current: "post-1",
            postID: "post-2"
        )

        XCTAssertEqual(presentedPostID, "post-2")
    }
}
