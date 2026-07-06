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

    @MainActor
    func testAttentionHintResolvedEventRefreshesLoadedDashboardContext() async throws {
        let activeHintSnapshot = HomeRealtimeDashboardFixtures.snapshot(
            selectedPetID: "pet-1",
            attentionHints: [
                try HomeRealtimeDashboardFixtures.attentionHint(id: "hint-1")
            ]
        )
        let resolvedHintSnapshot = HomeRealtimeDashboardFixtures.snapshot(selectedPetID: "pet-1")
        let dashboardRepository = ScriptedHomeDashboardRepository(
            results: [
                .success(MHBAPIResponse(success: true, code: "ok", message: "首页已加载", data: activeHintSnapshot)),
                .success(MHBAPIResponse(success: true, code: "ok", message: "首页已刷新", data: resolvedHintSnapshot))
            ]
        )
        let store = HomeDashboardStore(repository: dashboardRepository)
        let realtimeRepository = ScriptedHomeRealtimeRepository(events: [
            HomeRealtimeEvent(
                event: "attention_hint_resolved",
                petID: "pet-1",
                hintID: "hint-1",
                kind: "abnormal_followup_due",
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
        XCTAssertEqual(store.phase, .loaded(resolvedHintSnapshot.resolvingClientOwnedQuickActions()))
    }

    @MainActor
    func testTimelineChangedEventRefreshesLoadedDashboardContext() async throws {
        let initialSnapshot = HomeRealtimeDashboardFixtures.snapshot(selectedPetID: "pet-1")
        let updatedSnapshot = HomeRealtimeDashboardFixtures.snapshot(
            selectedPetID: "pet-1",
            recentTimeline: [
                HomeDashboardSnapshot.TimelineEvent(
                    id: "recovery-event-1",
                    eventKind: .health,
                    eventSubkind: "abnormal_recovery",
                    title: "恢复记录已写入",
                    subtitle: "馒头已恢复正常",
                    occurredText: "01:28",
                    occurredAt: "2026-07-06T17:28:11Z"
                )
            ]
        )
        let dashboardRepository = ScriptedHomeDashboardRepository(
            results: [
                .success(MHBAPIResponse(success: true, code: "ok", message: "首页已加载", data: initialSnapshot)),
                .success(MHBAPIResponse(success: true, code: "ok", message: "首页已刷新", data: updatedSnapshot))
            ]
        )
        let store = HomeDashboardStore(repository: dashboardRepository)
        let realtimeRepository = ScriptedHomeRealtimeRepository(events: [
            HomeRealtimeEvent(
                event: "timeline_changed",
                petID: "pet-1",
                hintID: nil,
                kind: "timeline_changed",
                sourceRefType: "pet_event",
                sourceRefID: "recovery-event-1",
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
        guard case .loaded(let snapshot) = store.phase else {
            XCTFail("首页应保持已加载状态")
            return
        }
        XCTAssertEqual(snapshot, updatedSnapshot.resolvingClientOwnedQuickActions())
    }
}
