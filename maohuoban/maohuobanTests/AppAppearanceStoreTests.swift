import SwiftUI
import XCTest
@testable import maohuoban

// AppAppearanceStoreTests App 外观偏好测试
// 核心职责：
// - 验证日夜模式设置写入真实偏好存储
// - 验证首页 Tab 不消费 App 外观偏好
@MainActor
final class AppAppearanceStoreTests: XCTestCase {
    func testDarkModePersistsAndResolvesDarkColorScheme() {
        let defaults = makeDefaults()
        let store = AppAppearanceStore(defaults: defaults)

        store.setDarkModeEnabled(true)

        XCTAssertEqual(store.mode, .dark)
        XCTAssertEqual(store.preferredColorScheme, .dark)
        XCTAssertEqual(defaults.string(forKey: AppAppearanceStore.defaultsKey), "dark")
    }

    func testFollowsSystemClearsPreferredColorScheme() {
        let defaults = makeDefaults()
        let store = AppAppearanceStore(defaults: defaults)

        store.setDarkModeEnabled(true)
        store.setFollowsSystem(true)

        XCTAssertEqual(store.mode, .system)
        XCTAssertNil(store.preferredColorScheme)
        XCTAssertEqual(defaults.string(forKey: AppAppearanceStore.defaultsKey), "system")
    }

    func testDisablingFollowsSystemFromSystemFallsBackToLightMode() {
        let defaults = makeDefaults()
        let store = AppAppearanceStore(defaults: defaults)

        store.setFollowsSystem(false)

        XCTAssertEqual(store.mode, .light)
        XCTAssertEqual(store.preferredColorScheme, .light)
        XCTAssertEqual(defaults.string(forKey: AppAppearanceStore.defaultsKey), "light")
    }

    func testHomeTabDoesNotApplyAppAppearancePreference() {
        XCTAssertFalse(MHBAppTab.home.appliesAppAppearancePreference)
        XCTAssertTrue(MHBAppTab.petWorld.appliesAppAppearancePreference)
        XCTAssertTrue(MHBAppTab.sameCity.appliesAppAppearancePreference)
        XCTAssertTrue(MHBAppTab.message.appliesAppAppearancePreference)
        XCTAssertTrue(MHBAppTab.profile.appliesAppAppearancePreference)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppAppearanceStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
