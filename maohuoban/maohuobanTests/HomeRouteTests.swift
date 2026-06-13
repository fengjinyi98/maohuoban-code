import XCTest
@testable import maohuoban

// HomeRouteTests 首页路由测试
// 核心职责：
// - 固化首页路由关联值契约
// - 防止商家待办入口丢失商家上下文
final class HomeRouteTests: XCTestCase {
    func testMerchantTaskRouteCarriesMerchantAndReminderIDs() {
        let route = HomeRoute.merchantTask(
            merchantID: "merchant-1",
            reminderID: "merchant-task-needs-record"
        )

        guard case .merchantTask(let merchantID, let reminderID) = route else {
            XCTFail("Expected merchant task route")
            return
        }

        XCTAssertEqual(merchantID, "merchant-1")
        XCTAssertEqual(reminderID, "merchant-task-needs-record")
    }
}
