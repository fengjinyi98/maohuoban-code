import XCTest
@testable import maohuoban

// MHBMockSystemTests Mock 数据开关测试
// 核心职责：
// - 固化本地联调默认使用后端数据
// - 保留显式启动参数和环境变量打开 Mock 数据
final class MHBMockSystemTests: XCTestCase {
    func testMockSystemUsesBackendDataByDefault() {
        XCTAssertFalse(
            MHBMockSystem.isEnabled(
                arguments: ["maohuoban"],
                environment: [:],
                isDebugBuild: true
            )
        )
    }

    func testMockSystemCanEnableMockDataExplicitly() {
        XCTAssertTrue(
            MHBMockSystem.isEnabled(
                arguments: ["maohuoban", "--use-mock-data"],
                environment: [:],
                isDebugBuild: true
            )
        )
        XCTAssertTrue(
            MHBMockSystem.isEnabled(
                arguments: ["maohuoban"],
                environment: ["MHB_USE_MOCK_DATA": "true"],
                isDebugBuild: true
            )
        )
    }

    func testBackendArgumentOverridesMockEnvironment() {
        XCTAssertFalse(
            MHBMockSystem.isEnabled(
                arguments: ["maohuoban", "--use-backend-data"],
                environment: ["MHB_USE_MOCK_DATA": "true"],
                isDebugBuild: true
            )
        )
    }
}
