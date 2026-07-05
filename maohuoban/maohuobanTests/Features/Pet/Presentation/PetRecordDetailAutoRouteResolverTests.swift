import XCTest
@testable import maohuoban

// PetRecordDetailAutoRouteResolverTests 记录详情自动路由测试
// 核心职责：
// - 验证引用点击只持有 event ID 时可解析到真实详情路由
// - 复用历史记录语义规则，避免详情路由分发规则分叉
@MainActor
final class PetRecordDetailAutoRouteResolverTests: XCTestCase {
    func testFeedingEventResolvesToFeedingDetailRoute() {
        let event = makeEvent(kind: .daily, subkind: "feeding", title: "最近喂食")
        let route = PetRecordDetailAutoRouteResolver.route(
            for: event,
            context: PetRecordEntryContext(petID: "pet-1", petName: "毛球")
        )

        XCTAssertEqual(
            route,
            .feeding(
                recordID: "event-1",
                context: PetRecordEntryContext(petID: "pet-1", petName: "毛球")
            )
        )
    }

    func testVaccineEventResolvesToVaccineDetailRoute() {
        let event = makeEvent(kind: .health, subkind: "vaccine", title: "疫苗完成")
        let route = PetRecordDetailAutoRouteResolver.route(
            for: event,
            context: PetRecordEntryContext(petID: "pet-1")
        )

        XCTAssertEqual(
            route,
            .vaccine(recordID: "event-1", context: PetRecordEntryContext(petID: "pet-1"))
        )
    }

    func testUnsupportedLifecycleEventStaysUnsupported() {
        let event = makeEvent(kind: .daily, subkind: "homecoming", title: "到家纪念")
        let route = PetRecordDetailAutoRouteResolver.route(
            for: event,
            context: PetRecordEntryContext(petID: "pet-1")
        )

        XCTAssertEqual(route, .unsupported(recordID: "event-1"))
    }

    private func makeEvent(
        kind: PetEventKind,
        subkind: String?,
        title: String
    ) -> PetEventDetail {
        PetEventDetail(
            id: "event-1",
            petID: "pet-1",
            litterID: nil,
            kind: kind,
            subkind: subkind,
            title: title,
            summary: nil,
            visibility: .private,
            occurredAt: "2026-07-05T10:00:00Z",
            recordRevision: 1,
            eventPayload: nil
        )
    }
}
