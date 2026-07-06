import Foundation

// HomeRealtimeRepository 首页实时事件仓库协议
// 核心职责：
// - 定义首页 SSE 事件流读取能力
// - 隔离 URLSession 和展示层状态刷新
protocol HomeRealtimeRepository {
    func openEventStream() -> AsyncThrowingStream<HomeRealtimeEvent, Error>
}
