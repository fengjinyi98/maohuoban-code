import XCTest
@testable import maohuoban

// HomeRealtimeEventConsumerTests 首页实时事件消费测试
// 核心职责：
// - 验证轻提醒投影事件会驱动首页 Store 刷新
// - 固化首页常驻刷新来自事件流而不是定时轮询
final class HomeRealtimeEventConsumerTests: XCTestCase {
    @MainActor
    func testAttentionHintProjectedEventRefreshesLoadedDashboardContext() async throws {
        let initialSnapshot = HomeRealtimeDashboardFixtures.snapshot(selectedPetID: "pet-1")
        let projectedHintSnapshot = HomeRealtimeDashboardFixtures.snapshot(
            selectedPetID: "pet-1",
            attentionHints: [
                try HomeRealtimeDashboardFixtures.attentionHint(id: "hint-1")
            ]
        )
        let dashboardRepository = ScriptedHomeDashboardRepository(
            results: [
                .success(MHBAPIResponse(success: true, code: "ok", message: "首页已加载", data: initialSnapshot)),
                .success(MHBAPIResponse(success: true, code: "ok", message: "首页已刷新", data: projectedHintSnapshot))
            ]
        )
        let store = HomeDashboardStore(repository: dashboardRepository)
        let realtimeRepository = ScriptedHomeRealtimeRepository(events: [
            HomeRealtimeEvent(
                event: "attention_hint_projected",
                petID: "pet-1",
                hintID: "hint-1",
                kind: "attention_hint_projected",
                sourceRefType: "agent_proactive_followup",
                sourceRefID: "followup-1",
                occurredAt: Date(timeIntervalSince1970: 0)
            )
        ])
        let consumer = HomeRealtimeEventConsumer(
            repository: realtimeRepository,
            store: store
        )

        await store.load(currentUserID: "user-1", selectedPetID: "pet-1")
        await consumer.consume()

        XCTAssertEqual(dashboardRepository.requestCount, 2)
        XCTAssertEqual(store.phase, .loaded(projectedHintSnapshot.resolvingClientOwnedQuickActions()))
    }
}
