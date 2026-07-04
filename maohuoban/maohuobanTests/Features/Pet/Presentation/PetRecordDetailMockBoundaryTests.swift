import XCTest
@testable import maohuoban

// PetRecordDetailMockBoundaryTests 宠物记录详情 mock 边界测试
// 核心职责：
// - 固化快速事实、喂食和异常详情只接收后端事件 ID 与入口上下文
// - 防止记录详情重新依赖本地演示宠物身份
@MainActor
final class PetRecordDetailMockBoundaryTests: XCTestCase {
    func testQuickFactPresentationUsesEntryContextPetIdentity() {
        let event = Self.makeEvent(
            id: "quick-fact-event-1",
            kind: .daily,
            subkind: "poop_normal",
            title: "便便正常",
            summary: "今天状态正常"
        )
        let presentation = PetQuickFactDetailPresentation(
            event: event,
            kind: .poopNormal,
            recordContext: Self.makeRecordContext()
        )

        guard case .pet(let pet) = presentation.rows.first?.value else {
            XCTFail("Expected first quick fact row to render pet identity")
            return
        }

        XCTAssertEqual(pet.id, "pet-1")
        XCTAssertEqual(pet.name, "糯米")
        XCTAssertEqual(pet.avatarPet.sex, .female)
        if case .asset(let assetName) = pet.avatarSource {
            XCTAssertNotEqual(assetName, "HomePetHeroMock")
        }
    }

    func testFeedingPresentationUsesEntryContextPetSexForAvatar() {
        let event = Self.makeEvent(
            id: "feeding-event-1",
            kind: .daily,
            subkind: "feeding",
            title: "已喂食",
            summary: nil
        )
        let presentation = PetFeedingDetailPresentation(
            event: event,
            recordContext: Self.makeRecordContext()
        )

        XCTAssertEqual(presentation.pet.id, "pet-1")
        XCTAssertEqual(presentation.pet.name, "糯米")
        XCTAssertEqual(presentation.pet.avatarPet.sex, .female)
    }

    func testTimelineResolverPreservesFeedingRecordIDAndContext() {
        let event = HomeDashboardSnapshot.TimelineEvent(
            id: "feeding-event-1",
            eventKind: .daily,
            title: "已喂食",
            subtitle: "主粮 · 正常",
            occurredText: "08:30",
            occurredAt: "2026-07-04T00:30:00Z"
        )
        let context = Self.makeRecordContext()

        let route = HomeTimelineRecordRouteResolver.route(for: event, recordContext: context)

        guard case .petRecordDetail(let detailRoute) = route,
              case .feeding(let recordID, let routeContext) = detailRoute else {
            XCTFail("Expected feeding event to route to feeding detail")
            return
        }
        XCTAssertEqual(recordID, "feeding-event-1")
        XCTAssertEqual(routeContext, context)
        XCTAssertEqual(detailRoute.id, "feeding-feeding-event-1")
    }

    func testTimelineResolverPreservesAbnormalRecordIDAndContext() {
        let event = HomeDashboardSnapshot.TimelineEvent(
            id: "abnormal-event-1",
            eventKind: .health,
            title: "异常记录",
            subtitle: "食欲、精神 · 明显",
            occurredText: "20:15",
            occurredAt: "2026-07-04T12:15:00Z"
        )
        let context = Self.makeRecordContext()

        let route = HomeTimelineRecordRouteResolver.route(for: event, recordContext: context)

        guard case .petRecordDetail(let detailRoute) = route,
              case .abnormal(let recordID, let routeContext) = detailRoute else {
            XCTFail("Expected abnormal event to route to abnormal detail")
            return
        }
        XCTAssertEqual(recordID, "abnormal-event-1")
        XCTAssertEqual(routeContext, context)
        XCTAssertEqual(detailRoute.id, "abnormal-abnormal-event-1")
    }

    func testRecordDetailDestinationAcceptsBackendEventRoutesAtCompileTime() {
        let context = Self.makeRecordContext()

        _ = PetRecordDetailDestinationScreen(
            route: .quickFact(recordID: "quick-fact-event-1", kind: .poopNormal, context: context),
            currentUserID: "user-1"
        )
        _ = PetRecordDetailDestinationScreen(
            route: .feeding(recordID: "feeding-event-1", context: context),
            currentUserID: "user-1"
        )
        _ = PetRecordDetailDestinationScreen(
            route: .abnormal(recordID: "abnormal-event-1", context: context),
            currentUserID: "user-1"
        )
    }
}

private extension PetRecordDetailMockBoundaryTests {
    static func makeRecordContext() -> PetRecordEntryContext {
        PetRecordEntryContext(
            petID: "pet-1",
            petName: "糯米",
            petAvatarURL: "/api/v1/media/assets/avatar-1/content",
            petSex: .female
        )
    }

    static func makeEvent(
        id: String,
        kind: PetEventKind,
        subkind: String,
        title: String,
        summary: String?
    ) -> PetEventDetail {
        PetEventDetail(
            id: id,
            petID: "pet-1",
            litterID: nil,
            kind: kind,
            subkind: subkind,
            title: title,
            summary: summary,
            visibility: .private,
            occurredAt: "2026-07-04T02:30:00Z",
            recordRevision: 1,
            eventPayload: nil
        )
    }
}
