import Foundation

// PendingConfirmationTask AI 确认任务状态
// 核心职责：
// - 承接后端 confirmation_task 稳定 SSE 事件
// - 让前端展示当前待确认问题
struct PendingConfirmationTask: Hashable {
    let id: String
    let questionText: String
    let preview: PendingConfirmationTaskPreview
    let actions: [PendingConfirmationTaskAction]
}

// PendingConfirmationTaskPreview 确认任务预览状态
// 核心职责：
// - 保存确认卡片需要展示的写入内容
// - 让用户授权前能看清本次写入意图
struct PendingConfirmationTaskPreview: Hashable {
    let title: String
    let eventSubkind: String?
    let note: String
    let sourceLabel: String?
}

// PendingConfirmationTaskAction 确认任务动作状态
// 核心职责：
// - 保存后端声明的确认任务操作
// - 支撑确认卡片按钮文案展示
struct PendingConfirmationTaskAction: Hashable {
    let kind: String
    let label: String
}
