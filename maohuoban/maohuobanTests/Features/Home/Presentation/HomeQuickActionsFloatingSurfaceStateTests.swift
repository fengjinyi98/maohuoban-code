import XCTest
@testable import maohuoban

// HomeQuickActionsFloatingSurfaceStateTests 首页快捷菜单 surface 状态测试
// 核心职责：
// - 固化单宿主膨胀面板的尺寸插值规则
// - 防止按钮与面板在动画中过渡到不稳定的中间形态
final class HomeQuickActionsFloatingSurfaceStateTests: XCTestCase {
    func testRowSpacingUsesSmallestSpacingToken() {
        XCTAssertEqual(
            HomeQuickActionsFloatingMetrics.rowSpacing,
            MHBTheme.Spacing.s1,
            accuracy: 0.001
        )
    }

    func testCollapsedStateUsesButtonMetrics() {
        let state = HomeQuickActionsFloatingSurfaceState(
            progress: 0,
            expandedWidth: 316,
            expandedHeight: 440
        )

        XCTAssertEqual(state.width, 58, accuracy: 0.001)
        XCTAssertEqual(state.height, 58, accuracy: 0.001)
        XCTAssertEqual(state.cornerRadius, 29, accuracy: 0.001)
        XCTAssertEqual(state.plusOpacity, 1, accuracy: 0.001)
        XCTAssertEqual(state.plusRotationDegrees, 0, accuracy: 0.001)
    }

    func testExpandedStateUsesPanelMetrics() {
        let state = HomeQuickActionsFloatingSurfaceState(
            progress: 1,
            expandedWidth: 316,
            expandedHeight: 440
        )

        XCTAssertEqual(state.width, 316, accuracy: 0.001)
        XCTAssertEqual(state.height, 440, accuracy: 0.001)
        XCTAssertEqual(state.cornerRadius, 20, accuracy: 0.001)
        XCTAssertEqual(state.plusOpacity, 0, accuracy: 0.001)
        XCTAssertEqual(state.plusRotationDegrees, 45, accuracy: 0.001)
    }

    func testIntermediateStateInterpolatesSurfaceWithoutIdentitySwitch() {
        let state = HomeQuickActionsFloatingSurfaceState(
            progress: 0.5,
            expandedWidth: 316,
            expandedHeight: 440
        )

        XCTAssertEqual(state.width, 187, accuracy: 0.001)
        XCTAssertEqual(state.height, 249, accuracy: 0.001)
        XCTAssertEqual(state.cornerRadius, 24.5, accuracy: 0.001)
        XCTAssertEqual(state.plusOpacity, 0.5, accuracy: 0.001)
        XCTAssertEqual(state.plusRotationDegrees, 22.5, accuracy: 0.001)
    }
}
