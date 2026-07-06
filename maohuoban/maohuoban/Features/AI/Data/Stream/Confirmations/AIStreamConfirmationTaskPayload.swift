import Foundation

struct AIStreamConfirmationTaskPayload: Decodable {
    let taskID: UUID
    let questionText: String
    let preview: AIStreamConfirmationTaskPreviewPayload
    let actions: [AIStreamConfirmationTaskActionPayload]

    enum CodingKeys: String, CodingKey {
        case taskID = "confirmation_task_id"
        case questionText = "question_text"
        case preview
        case actions
    }
}

// AIStreamConfirmationTaskPreviewPayload 确认任务预览 DTO
// 核心职责：
// - 承接后端确认卡片预览内容
// - 让前端展示即将写入的具体观察文本
struct AIStreamConfirmationTaskPreviewPayload: Decodable, Hashable {
    let title: String
    let eventSubkind: String?
    let note: String
    let sourceLabel: String?

    enum CodingKeys: String, CodingKey {
        case title
        case eventSubkind = "event_subkind"
        case note
        case sourceLabel = "source_label"
    }
}

// AIStreamConfirmationTaskActionPayload 确认任务动作 DTO
// 核心职责：
// - 承接后端允许的确认操作
// - 让 UI 文案和动作类型来自稳定合同
struct AIStreamConfirmationTaskActionPayload: Decodable, Hashable {
    let kind: String
    let label: String
}
