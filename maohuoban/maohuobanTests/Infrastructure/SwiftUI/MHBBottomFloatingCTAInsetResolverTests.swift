import XCTest
@testable import maohuoban

// MHBBottomFloatingCTAInsetResolverTests 底部悬浮按钮间距测试
// 核心职责：
// - 固化键盘出现时底部安全区不会重复叠加键盘高度
// - 固化设备底部安全区仍参与按钮底部定位
final class MHBBottomFloatingCTAInsetResolverTests: XCTestCase {
    func testUsesDeviceBottomInsetWhenKeyboardIsHidden() {
        let inset = MHBBottomFloatingCTAInsetResolver.effectiveBottomInset(
            geometryBottomInset: 34
        )

        XCTAssertEqual(inset, 34)
    }

    func testIgnoresKeyboardHeightPresentedAsGeometryBottomInset() {
        let inset = MHBBottomFloatingCTAInsetResolver.effectiveBottomInset(
            geometryBottomInset: 345
        )

        XCTAssertEqual(inset, 0)
    }

    func testKeepsCompactKeyboardAccessoryInset() {
        let inset = MHBBottomFloatingCTAInsetResolver.effectiveBottomInset(
            geometryBottomInset: 75
        )

        XCTAssertEqual(inset, 75)
    }
}
