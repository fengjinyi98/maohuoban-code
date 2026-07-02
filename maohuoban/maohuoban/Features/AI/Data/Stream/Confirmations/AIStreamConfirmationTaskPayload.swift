import Foundation

struct AIStreamConfirmationTaskPayload: Decodable {
    let taskID: UUID
    let questionText: String

    enum CodingKeys: String, CodingKey {
        case taskID = "confirmation_task_id"
        case questionText = "question_text"
    }
}
