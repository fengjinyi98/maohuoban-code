import XCTest
@testable import maohuoban

// PetPantryMediaURLResolverTests 储物柜媒资地址解析测试
// 核心职责：
// - 固定后端相对媒资地址在储物柜展示层可解析
// - 避免不同储物柜展示组件各自散写 URL 解析规则
@MainActor
final class PetPantryMediaURLResolverTests: XCTestCase {
    func testResolveRelativeCoverURL() {
        let url = PantryMediaURLResolver.resolve("/api/v1/media/assets/asset-1/content")

        XCTAssertEqual(url?.path, "/api/v1/media/assets/asset-1/content")
        XCTAssertNotNil(url?.scheme)
    }

    func testResolveAbsoluteCoverURL() {
        let url = PantryMediaURLResolver.resolve("https://example.com/media/asset-1.jpg")

        XCTAssertEqual(url?.absoluteString, "https://example.com/media/asset-1.jpg")
    }
}
