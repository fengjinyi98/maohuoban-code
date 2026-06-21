import XCTest
@testable import maohuoban

// HomeRouteTests 首页路由测试
// 核心职责：
// - 固化首页路由关联值契约
// - 防止商家待办入口丢失商家上下文
final class HomeRouteTests: XCTestCase {
    @MainActor
    func testPetAssistantRouteCarriesCurrentPetContext() {
        let route = HomeRoute.petAssistant(
            AIAssistantEntryContext(
                selectedPetID: "pet-1",
                selectedPetName: "糯米"
            )
        )

        guard case .petAssistant(let context) = route else {
            XCTFail("Expected pet assistant route")
            return
        }

        XCTAssertEqual(context.selectedPetID, "pet-1")
        XCTAssertEqual(context.selectedPetName, "糯米")
        XCTAssertEqual(route.systemImage, "sparkles")
    }

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

    @MainActor
    func testHealthReminderRoutesToTimelineEventDetail() {
        let reminder = HomeDashboardSnapshot.Reminder(
            id: "event-1",
            kind: .deworming,
            title: "内外驱虫",
            subtitle: "预计 2026-06-16 提醒",
            dueText: "待提醒",
            remarks: nil
        )
        let context = HomeActionRoutingContext(selectedPetID: "pet-1")

        let route = HomeReminderRouteResolver.route(for: reminder, context: context)

        guard case .timelineEvent(let eventID) = route else {
            XCTFail("Expected timeline event route")
            return
        }
        XCTAssertEqual(eventID, "event-1")
    }

    @MainActor
    func testMerchantReminderRoutesToMerchantTaskWhenMerchantContextExists() {
        let reminder = HomeDashboardSnapshot.Reminder(
            id: "merchant-task-needs-record",
            kind: .merchantTask,
            title: "待补健康记录",
            subtitle: "3 只宠物缺少买家可见健康信息",
            dueText: "今日",
            remarks: nil
        )
        let context = HomeActionRoutingContext(merchantID: "merchant-1")

        let route = HomeReminderRouteResolver.route(for: reminder, context: context)

        guard case .merchantTask(let merchantID, let reminderID) = route else {
            XCTFail("Expected merchant task route")
            return
        }
        XCTAssertEqual(merchantID, "merchant-1")
        XCTAssertEqual(reminderID, "merchant-task-needs-record")
    }

    @MainActor
    func testMerchantReminderWithoutMerchantContextHasNoRoute() {
        let reminder = HomeDashboardSnapshot.Reminder(
            id: "merchant-task-needs-record",
            kind: .merchantTask,
            title: "待补健康记录",
            subtitle: "3 只宠物缺少买家可见健康信息",
            dueText: "今日",
            remarks: nil
        )

        let route = HomeReminderRouteResolver.route(
            for: reminder,
            context: HomeActionRoutingContext()
        )

        XCTAssertNil(route)
    }
}
