import Foundation

// ActiveToolStatus AI 工具态状态
// 核心职责：
// - 承接后端 tool_call 稳定 SSE 事件
// - 保留兼容工具状态，UI 进度文案由 agent_activity 驱动
struct ActiveToolStatus: Hashable {
    let toolName: String
    let status: String
    let citationCount: Int
}
