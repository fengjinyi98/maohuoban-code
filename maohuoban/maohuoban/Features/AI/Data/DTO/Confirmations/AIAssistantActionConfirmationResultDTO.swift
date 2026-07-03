import Foundation

// AIAssistantActionConfirmationResultDTO 建议动作确认结果 DTO
// 核心职责：
// - 解码后端饮食确认接口返回的事件与配置 ID
// - 让 Store 只关心确认是否成功
struct AIAssistantActionConfirmationResultDTO: Decodable, Equatable {
    let confirmedEventID: UUID
    let assignmentID: UUID?
    let correctionEventID: UUID?

    enum CodingKeys: String, CodingKey {
        case confirmedEventID = "confirmed_event_id"
        case assignmentID = "assignment_id"
        case correctionEventID = "correction_event_id"
    }
}
