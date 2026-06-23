import XCTest
@testable import maohuoban

// SettingsMockStoreTests 设置 Mock 状态源测试
// 核心职责：
// - 验证设置功能在后端未接入时可加载设备会话 mock 数据
// - 验证移除设备会同步更新列表与详情缓存
@MainActor
final class SettingsMockStoreTests: XCTestCase {
    func testMockDeviceSessionStoreLoadsDevices() async {
        let store = SettingsDeviceSessionStore(repository: MockSettingsDeviceSessionRepository())

        await store.loadDevices()

        XCTAssertFalse(store.devices.isEmpty)
        XCTAssertNil(store.lastErrorMessage)
    }

    func testRemovingMockDeviceUpdatesDevicesAndDetails() async {
        let store = SettingsDeviceSessionStore(repository: MockSettingsDeviceSessionRepository())
        await store.loadDevices()
        let sessionID = try! XCTUnwrap(store.devices.first?.sessionID)

        await store.loadDetails(sessionID: sessionID)
        await store.removeDevice(sessionID: sessionID)

        XCTAssertFalse(store.devices.contains { $0.sessionID == sessionID })
        XCTAssertNil(store.deviceDetails[sessionID])
        XCTAssertEqual(store.toastMessage, "登录设备已移除")
    }
}
