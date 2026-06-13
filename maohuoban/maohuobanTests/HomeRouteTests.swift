import XCTest
@testable import maohuoban

// HomeRouteTests 首页路由测试
// 核心职责：
// - 固化首页路由关联值契约
// - 防止商家待办入口丢失商家上下文
final class HomeRouteTests: XCTestCase {
    @MainActor
    func testBookHospitalRouteCarriesPetAndCityContext() {
        let action = HomeDashboardSnapshot.Action(
            kind: .bookHospital,
            title: "预约医院",
            subtitle: "体检 / 复诊"
        )
        let context = HomeActionRoutingContext(
            selectedPetID: "pet-1",
            merchantID: nil,
            city: "成都"
        )

        let route = HomeActionRouteResolver.route(for: action, context: context)

        guard case .bookHospital(let petID, let city) = route else {
            XCTFail("Expected hospital booking route")
            return
        }

        XCTAssertEqual(petID, "pet-1")
        XCTAssertEqual(city, "成都")
    }

    @MainActor
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
