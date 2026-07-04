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
    func testPoopNormalActionBuildsQuickFactPayload() {
        let occurredAt = Date(timeIntervalSince1970: 0)
        let submissionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        let draft = HomeQuickFactAction.poopNormal.eventDraft(
            occurredAt: occurredAt,
            submissionID: submissionID
        )

        XCTAssertEqual(
            draft,
            PetEventDraft(
                kind: .daily,
                subkind: "quick_fact",
                title: "便便正常",
                summary: "粪便状态：健康成型",
                visibility: .private,
                occurredAt: "1970-01-01T00:00:00Z",
                eventPayload: [
                    "quick_fact_kind": .string("poop_normal"),
                    "quick_fact_submission_id": .string("00000000-0000-0000-0000-000000000001")
                ]
            )
        )
    }

    @MainActor
    func testEnergyNormalActionBuildsQuickFactPayload() {
        let occurredAt = Date(timeIntervalSince1970: 0)
        let submissionID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        let draft = HomeQuickFactAction.energyNormal.eventDraft(
            occurredAt: occurredAt,
            submissionID: submissionID
        )

        XCTAssertEqual(
            draft,
            PetEventDraft(
                kind: .daily,
                subkind: "quick_fact",
                title: "精神不错",
                summary: "精神与活力：正常平稳",
                visibility: .private,
                occurredAt: "1970-01-01T00:00:00Z",
                eventPayload: [
                    "quick_fact_kind": .string("energy_normal"),
                    "quick_fact_submission_id": .string("00000000-0000-0000-0000-000000000002")
                ]
            )
        )
    }

    @MainActor
    func testAppetiteNormalActionBuildsQuickFactPayload() {
        let occurredAt = Date(timeIntervalSince1970: 0)
        let submissionID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

        let draft = HomeQuickFactAction.appetiteNormal.eventDraft(
            occurredAt: occurredAt,
            submissionID: submissionID
        )

        XCTAssertEqual(
            draft,
            PetEventDraft(
                kind: .daily,
                subkind: "quick_fact",
                title: "食欲正常",
                summary: "食欲正常",
                visibility: .private,
                occurredAt: "1970-01-01T00:00:00Z",
                eventPayload: [
                    "quick_fact_kind": .string("appetite_normal"),
                    "quick_fact_submission_id": .string("00000000-0000-0000-0000-000000000003")
                ]
            )
        )
    }

    @MainActor
    func testAbnormalActionDoesNotUseQuickFactRouteResolver() {
        let context = HomeActionRoutingContext(
            selectedPetID: "pet-1",
            selectedPetName: "糯米",
            selectedPetSex: .female
        )

        let route = HomeQuickFactActionRouteResolver.route(
            for: .abnormal,
            context: context
        )

        XCTAssertNil(route)
    }

    @MainActor
    func testAbnormalActionDoesNotCreateDirectEventDraft() {
        let occurredAt = Date(timeIntervalSince1970: 0)
        let submissionID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!

        XCTAssertNil(
            HomeQuickFactAction.abnormal.eventDraft(
                occurredAt: occurredAt,
                submissionID: submissionID
            )
        )
    }

    @MainActor
    func testFedActionDoesNotCreateDirectEventDraft() {
        let occurredAt = Date(timeIntervalSince1970: 0)
        let submissionID = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!

        XCTAssertNil(
            HomeQuickFactAction.fed.eventDraft(
                occurredAt: occurredAt,
                submissionID: submissionID
            )
        )
    }

}
