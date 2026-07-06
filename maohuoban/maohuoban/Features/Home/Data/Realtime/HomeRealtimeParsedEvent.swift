import Foundation

// HomeRealtimeParsedEvent 首页 SSE 解析结果
// 核心职责：
// - 保留原始 event 名称用于判断事件类型
// - 承载已成功解码的首页实时事件
struct HomeRealtimeParsedEvent {
    let eventName: String
    let data: String
    let event: HomeRealtimeEvent?
}
