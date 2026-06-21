import XCTest
@testable import maohuoban

// PetWorldFeedDetailMoreMenuActionResolverTests 详情页更多菜单动作测试
// 核心职责：
// - 固化作者态下的更多菜单展示规则
// - 防止删除和举报入口在本人帖子详情中回归
final class PetWorldFeedDetailMoreMenuActionResolverTests: XCTestCase {
    func testOwnedPostOnlyShowsShareAction() {
        let actions = PetWorldFeedDetailMoreMenuActionResolver.actions(
            isOwnedByCurrentUser: true
        )

        XCTAssertEqual(actions, [.share])
    }

    func testOtherUsersPostShowsShareAndReportActions() {
        let actions = PetWorldFeedDetailMoreMenuActionResolver.actions(
            isOwnedByCurrentUser: false
        )

        XCTAssertEqual(actions, [.share, .report])
    }
}
