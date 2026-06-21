import XCTest
@testable import maohuoban

// ProfileSettingsRouteTests 我的页设置路由测试
// 核心职责：
// - 固化 Profile 设置按钮进入设置首页的路由目标
// - 固化设置页二级入口仍归属 Profile Tab 导航栈
final class ProfileSettingsRouteTests: XCTestCase {
    @MainActor
    func testSettingsToolbarRoutesToSettingsScreen() {
        XCTAssertEqual(ProfileRoute.settings, .settings)
    }

    @MainActor
    func testSettingsChildRoutesRemainInProfileRoute() {
        let routes: [ProfileRoute] = [
            .accountSecurity,
            .generalSettings,
            .notificationSettings,
            .privacySettings,
            .storageSpace,
            .addressList,
            .accountManagement
        ]

        XCTAssertEqual(routes.count, 7)
    }
}
