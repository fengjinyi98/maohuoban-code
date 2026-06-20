import XCTest
@testable import maohuoban

// HomeActionRouteResolverTests 首页动作路由测试
// 核心职责：
// - 固化首页快捷动作到导航目标的映射
// - 确认普通用户和商家动作携带最小上下文
final class HomeActionRouteResolverTests: XCTestCase {
    @MainActor
    func testCreatePetActionRoutesToCreatePetFlow() {
        let snapshot = HomeDashboardSnapshot.homeTestSnapshot()
        let action = HomeDashboardSnapshot.Action(
            kind: .createPet,
            title: "创建宠物",
            subtitle: nil
        )

        let route = HomeActionRouteResolver.route(
            for: action,
            context: HomeActionRoutingContext(snapshot: snapshot)
        )

        XCTAssertEqual(route, .createPet)
    }

    @MainActor
    func testHealthRecordActionCarriesCurrentPetID() {
        let snapshot = HomeDashboardSnapshot.homeTestSnapshot(selectedPetID: "pet-1")
        let action = HomeDashboardSnapshot.Action(
            kind: .healthRecord,
            title: "健康记录",
            subtitle: nil
        )

        let route = HomeActionRouteResolver.route(
            for: action,
            context: HomeActionRoutingContext(snapshot: snapshot)
        )

        XCTAssertEqual(route, .recordHealth(petID: "pet-1"))
    }

    @MainActor
    func testDailyRecordActionRoutesToPublishWithCurrentPetContext() {
        let snapshot = HomeDashboardSnapshot.homeTestSnapshot(selectedPetID: "pet-1")
        let action = HomeDashboardSnapshot.Action(
            kind: .dailyRecord,
            title: "记录日常",
            subtitle: nil
        )

        let route = HomeActionRouteResolver.route(
            for: action,
            context: HomeActionRoutingContext(snapshot: snapshot)
        )

        XCTAssertEqual(
            route,
            .publishEvent(
                PublishEntryContext(
                    source: .home,
                    selectedPetID: "pet-1",
                    selectedPetName: "糯米"
                )
            )
        )
    }

    @MainActor
    func testMerchantActionCarriesMerchantID() {
        let snapshot = HomeDashboardSnapshot.homeTestSnapshot(merchantID: "merchant-1")
        let action = HomeDashboardSnapshot.Action(
            kind: .addMerchantPet,
            title: "新增宠物",
            subtitle: nil
        )

        let route = HomeActionRouteResolver.route(
            for: action,
            context: HomeActionRoutingContext(snapshot: snapshot)
        )

        XCTAssertEqual(route, .addMerchantPet(merchantID: "merchant-1"))
    }

    @MainActor
    func testMerchantActionWithoutMerchantIDHasNoRoute() {
        let snapshot = HomeDashboardSnapshot.homeTestSnapshot()
        let action = HomeDashboardSnapshot.Action(
            kind: .publishAvailableStatus,
            title: "发布可售状态",
            subtitle: nil
        )

        let route = HomeActionRouteResolver.route(
            for: action,
            context: HomeActionRoutingContext(snapshot: snapshot)
        )

        XCTAssertNil(route)
    }
}
