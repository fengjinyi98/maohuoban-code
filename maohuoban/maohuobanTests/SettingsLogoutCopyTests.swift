import XCTest
@testable import maohuoban

// SettingsLogoutCopyTests 设置页退出登录文案测试
// 核心职责：
// - 锁定退出登录确认面板使用传入用户名
// - 避免设置页回退到硬编码 mock 文案
final class SettingsLogoutCopyTests: XCTestCase {
    func testLogoutConfirmationMessageUsesProvidedUsername() {
        XCTAssertEqual(
            SettingsLogoutSheetMessageBuilder.confirmationMessage(username: "阿毛"),
            "确认退出该账号 @阿毛 吗？"
        )
    }
}
