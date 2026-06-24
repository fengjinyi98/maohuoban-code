import XCTest
@testable import maohuoban

// HomeQuickFactActionTests 首页快捷事实动作测试
// 核心职责：
// - 固定首页底部快捷事实条的动作顺序
// - 验证正常事实直接生成宠物日常事件，异常入口进入健康记录
final class HomeQuickFactActionTests: XCTestCase {
    @MainActor
    func testDefaultActionsKeepLowFrictionOrder() {
        XCTAssertEqual(
            HomeQuickFactAction.defaultActions,
            [.fed, .poopNormal, .energyNormal, .appetiteNormal, .abnormal]
        )
    }

    @MainActor
    func testFedActionBuildsPrivateDailyEventDraft() {
        let occurredAt = Date(timeIntervalSince1970: 0)

        let draft = HomeQuickFactAction.fed.eventDraft(occurredAt: occurredAt)

        XCTAssertEqual(
            draft,
            PetEventDraft(
                kind: .daily,
                subkind: "quick_fact",
                title: "已喂",
                summary: "完成喂食",
                visibility: .private,
                occurredAt: "1970-01-01T00:00:00Z"
            )
        )
    }

    @MainActor
    func testAbnormalActionRoutesToHealthRecordWithCurrentPetContext() {
        let context = HomeActionRoutingContext(
            selectedPetID: "pet-1",
            selectedPetName: "糯米",
            selectedPetSex: .female
        )

        let route = HomeQuickFactActionRouteResolver.route(
            for: .abnormal,
            context: context
        )

        XCTAssertEqual(
            route,
            .recordHealth(
                PetRecordEntryContext(
                    petID: "pet-1",
                    petName: "糯米",
                    petSex: .female
                )
            )
        )
    }

    @MainActor
    func testAbnormalActionDoesNotCreateDirectEventDraft() {
        let occurredAt = Date(timeIntervalSince1970: 0)

        XCTAssertNil(HomeQuickFactAction.abnormal.eventDraft(occurredAt: occurredAt))
    }

}
