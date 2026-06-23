import XCTest
@testable import maohuoban

// MHBBackendEndpointTests 后端地址配置测试
// 核心职责：
// - 固化 UI Test 启动参数覆盖后端地址的解析规则
// - 避免联调测试误连默认局域网后端
@MainActor
final class MHBBackendEndpointTests: XCTestCase {
    func testLocalDevelopmentBaseURLUsesLaunchArgumentOverride() {
        let url = MHBBackendEndpoint.localDevelopmentBaseURL(
            environment: [:],
            arguments: [
                "/path/to/maohuoban",
                "-MHB_BACKEND_BASE_URL",
                "http://127.0.0.1:18080"
            ],
            userDefaultsURLString: nil
        )

        XCTAssertEqual(url.absoluteString, "http://127.0.0.1:18080")
    }
}
