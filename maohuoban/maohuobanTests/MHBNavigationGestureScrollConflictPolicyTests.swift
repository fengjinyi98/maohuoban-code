import CoreGraphics
import XCTest
@testable import maohuoban

// MHBNavigationGestureScrollConflictPolicyTests 导航手势滚动冲突测试
// 核心职责：
// - 固化系统侧滑返回与横向滚动视图的冲突判定
// - 防止横向内容离开最左侧时误触发返回
final class MHBNavigationGestureScrollConflictPolicyTests: XCTestCase {
    func testAllowsPopGestureWhenHorizontalScrollViewIsAtLeadingEdge() {
        let shouldAllow = MHBNavigationGestureScrollConflictPolicy.shouldAllowPopGesture(
            contentSize: CGSize(width: 600, height: 100),
            bounds: CGRect(x: 0, y: 0, width: 300, height: 100),
            contentOffset: CGPoint(x: 0, y: 0),
            adjustedContentInsetLeft: 0
        )

        XCTAssertTrue(shouldAllow)
    }

    func testBlocksPopGestureWhenHorizontalScrollViewHasMovedAwayFromLeadingEdge() {
        let shouldAllow = MHBNavigationGestureScrollConflictPolicy.shouldAllowPopGesture(
            contentSize: CGSize(width: 600, height: 100),
            bounds: CGRect(x: 0, y: 0, width: 300, height: 100),
            contentOffset: CGPoint(x: 24, y: 0),
            adjustedContentInsetLeft: 0
        )

        XCTAssertFalse(shouldAllow)
    }

    func testAllowsPopGestureWhenContentDoesNotOverflowHorizontally() {
        let shouldAllow = MHBNavigationGestureScrollConflictPolicy.shouldAllowPopGesture(
            contentSize: CGSize(width: 300, height: 100),
            bounds: CGRect(x: 0, y: 0, width: 300, height: 100),
            contentOffset: CGPoint(x: 24, y: 0),
            adjustedContentInsetLeft: 0
        )

        XCTAssertTrue(shouldAllow)
    }
}
