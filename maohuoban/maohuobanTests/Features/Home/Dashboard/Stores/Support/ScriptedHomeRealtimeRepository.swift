import Foundation
@testable import maohuoban

// ScriptedHomeRealtimeRepository 脚本化首页实时事件仓库
// 核心职责：
// - 向事件消费器提供指定事件序列
// - 避免测试依赖真实 URLSession
struct ScriptedHomeRealtimeRepository: HomeRealtimeRepository {
    let events: [HomeRealtimeEvent]

    func openEventStream() -> AsyncThrowingStream<HomeRealtimeEvent, Error> {
        AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}
