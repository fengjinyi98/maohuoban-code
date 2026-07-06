import Foundation

// AIConfirmationTaskApprovalStreamRequestBody 确认任务授权流请求体
// 核心职责：
// - 承载确认任务 approve/stream 入口的前端 surface
// - 保持授权命令不包含聊天消息文本
struct AIConfirmationTaskApprovalStreamRequestBody: Encodable {
    let surface: String
}
