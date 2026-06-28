import Foundation

// ActiveToolStatus AI 工具态状态
// 核心职责：
// - 承接后端 tool_call 稳定 SSE 事件
// - 让前端展示当前工具执行状态
struct ActiveToolStatus: Hashable {
    let toolName: String
    let status: String
    let citationCount: Int
}
