import Foundation

// PendingConfirmationTask AI 确认任务状态
// 核心职责：
// - 承接后端 confirmation_task 稳定 SSE 事件
// - 让前端展示当前待确认问题
struct PendingConfirmationTask: Hashable {
    let id: String
    let questionText: String
}
