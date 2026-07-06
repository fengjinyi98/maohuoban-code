import Foundation

// AIConfirmationTaskMutationResultDTO 确认任务变更结果 DTO
// 核心职责：
// - 承接后端确认任务确认/取消后的状态
// - 支撑前端清理 pending confirmation UI
struct AIConfirmationTaskMutationResultDTO: Decodable {
    let confirmationTaskID: UUID
    let status: String

    enum CodingKeys: String, CodingKey {
        case confirmationTaskID = "confirmation_task_id"
        case status
    }
}
