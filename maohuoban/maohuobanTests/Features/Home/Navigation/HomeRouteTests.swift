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
    func testPetAlbumRouteCarriesEntrySourceContext() {
        let context = PetAlbumEntryContext(
            petID: "pet-1",
            petName: "糯米"
        )
        let route = HomeRoute.petAlbum(context)

        guard case .petAlbum(let actualContext) = route else {
            XCTFail("Expected pet album entry route")
            return
        }

        XCTAssertEqual(actualContext, context)
        XCTAssertEqual(route.systemImage, "photo.on.rectangle.angled")
        XCTAssertEqual(route.title, "宠物相册")
    }

    @MainActor
    func testPetPantryRouteCarriesEntryContextWithoutOwningPetScope() {
        let context = PetPantryEntryContext(
            sourcePetID: "pet-1",
            sourcePetName: "糯米"
        )
        let route = HomeRoute.petPantry(context)

        guard case .petPantry(let actualContext) = route else {
            XCTFail("Expected pantry entry route")
            return
        }

        XCTAssertEqual(actualContext, context)
        XCTAssertEqual(actualContext.sourcePetID, "pet-1")
        XCTAssertEqual(actualContext.sourcePetName, "糯米")
        XCTAssertEqual(route.subtitle, "进入用户储物柜")
    }

    @MainActor
    func testHealthReminderRoutesToTimelineEventDetail() {
        let reminder = HomeDashboardSnapshot.Reminder(
            id: "event-1",
            kind: .deworming,
            title: "内外驱虫",
            subtitle: "预计 2026-06-16 提醒",
            dueText: "待提醒",
            remarks: nil,
            sourceRef: nil
        )
        let context = HomeActionRoutingContext(selectedPetID: "pet-1")

        let route = HomeReminderRouteResolver.route(for: reminder, context: context)

        guard case .petRecordDetail = route else {
            XCTFail("Expected pet record detail route")
            return
        }
        XCTAssertNotNil(route)
    }

    @MainActor
    func testWeightTimelineEventRoutesToWeightRecordDetailWithPetContext() {
        let event = HomeDashboardSnapshot.TimelineEvent(
            id: "weight-record-1",
            eventKind: .weight,
            title: "记录体重",
            subtitle: "4.20 kg",
            occurredText: "09:30",
            occurredAt: "2026-07-04T01:30:00Z"
        )
        let context = PetRecordEntryContext(
            petID: "pet-1",
            petName: "糯米",
            petAvatarURL: "/media/pet/avatar",
            petSex: .female
        )

        let route = HomeTimelineRecordRouteResolver.route(
            for: event,
            recordContext: context
        )

        guard case .petWeightRecordDetail(let recordID, let routeContext) = route else {
            XCTFail("Expected real weight record detail route")
            return
        }
        XCTAssertEqual(recordID, "weight-record-1")
        XCTAssertEqual(routeContext, context)
    }

    @MainActor
    func testQuickFactTimelineEventPreservesBackendRecordID() {
        let event = HomeDashboardSnapshot.TimelineEvent(
            id: "quick-fact-event-1",
            eventKind: .daily,
            title: "便便正常",
            subtitle: "状态正常",
            occurredText: "10:30",
            occurredAt: "2026-07-04T02:30:00Z"
        )
        let context = PetRecordEntryContext(
            petID: "pet-1",
            petName: "糯米",
            petAvatarURL: "/media/pet/avatar",
            petSex: .female
        )

        let route = HomeTimelineRecordRouteResolver.route(
            for: event,
            recordContext: context
        )

        guard case .petRecordDetail(let detailRoute) = route else {
            XCTFail("Expected pet record detail route")
            return
        }
        guard case .quickFact(let recordID, let kind, let routeContext) = detailRoute else {
            XCTFail("Expected quick fact detail route")
            return
        }
        XCTAssertEqual(recordID, "quick-fact-event-1")
        XCTAssertEqual(kind, .poopNormal)
        XCTAssertEqual(routeContext, context)
        XCTAssertEqual(detailRoute.id, "quickFact-quick-fact-event-1")
    }

    @MainActor
    func testMerchantReminderRoutesToMerchantTaskWhenMerchantContextExists() {
        let reminder = HomeDashboardSnapshot.Reminder(
            id: "merchant-task-needs-record",
            kind: .merchantTask,
            title: "待补健康记录",
            subtitle: "3 只宠物缺少买家可见健康信息",
            dueText: "今日",
            remarks: nil,
            sourceRef: nil
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
            remarks: nil,
            sourceRef: nil
        )

        let route = HomeReminderRouteResolver.route(
            for: reminder,
            context: HomeActionRoutingContext()
        )

        XCTAssertNil(route)
    }
}
