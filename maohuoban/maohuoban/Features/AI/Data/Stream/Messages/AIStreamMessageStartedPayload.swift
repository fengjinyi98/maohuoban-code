import Foundation

struct AIStreamMessageStartedPayload: Decodable {
    let chatSessionID: UUID
    let messageID: UUID
    let title: String

    enum CodingKeys: String, CodingKey {
        case chatSessionID = "chat_session_id"
        case messageID = "message_id"
        case title
    }
}
