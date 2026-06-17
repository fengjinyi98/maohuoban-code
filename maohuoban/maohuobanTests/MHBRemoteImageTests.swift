import XCTest
@testable import maohuoban

// MHBRemoteImageTests 远程图片组件测试
// 核心职责：
// - 固化远程图片请求的缓存策略
// - 防止调用点绕过统一请求构造
@MainActor
final class MHBRemoteImageTests: XCTestCase {
    func testRequestUsesProtocolCachePolicyByDefault() throws {
        let url = try XCTUnwrap(URL(string: "https://img.maohuoban.test/pet.png"))

        let request = MHBRemoteImageRequestFactory.request(url: url)

        XCTAssertEqual(request.url, url)
        XCTAssertEqual(request.cachePolicy, .useProtocolCachePolicy)
        XCTAssertEqual(request.timeoutInterval, 30)
    }

    func testRequestAllowsCustomCachePolicyAndTimeout() throws {
        let url = try XCTUnwrap(URL(string: "https://img.maohuoban.test/avatar.png"))

        let request = MHBRemoteImageRequestFactory.request(
            url: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 12
        )

        XCTAssertEqual(request.url, url)
        XCTAssertEqual(request.cachePolicy, .returnCacheDataElseLoad)
        XCTAssertEqual(request.timeoutInterval, 12)
    }
}
