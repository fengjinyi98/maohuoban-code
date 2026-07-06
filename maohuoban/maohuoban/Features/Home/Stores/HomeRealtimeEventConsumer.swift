import Foundation

// HomeRealtimeEventConsumer 首页实时事件消费器
// 核心职责：
// - 订阅后端首页 SSE 事件
// - 在收到首页读模型变更事件后触发首页 Store 刷新
@MainActor
struct HomeRealtimeEventConsumer {
    private let repository: HomeRealtimeRepository
    private let store: HomeDashboardStore

    init(
        repository: HomeRealtimeRepository = DefaultHomeRealtimeRepository(),
        store: HomeDashboardStore
    ) {
        self.repository = repository
        self.store = store
    }

    func consume() async {
        do {
            for try await event in repository.openEventStream() {
                guard Self.shouldRefreshDashboard(for: event) else {
                    continue
                }
                await store.refreshLoadedContext()
            }
        } catch {
        }
    }

    private static func shouldRefreshDashboard(for event: HomeRealtimeEvent) -> Bool {
        event.event == "attention_hint_projected"
            || event.event == "attention_hint_resolved"
            || event.event == "timeline_changed"
    }
}
