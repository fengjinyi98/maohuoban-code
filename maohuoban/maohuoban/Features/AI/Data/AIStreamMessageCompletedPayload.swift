import Foundation

struct AIStreamMessageCompletedPayload: Decodable {
    let messageID: UUID
    let finalText: String
    let citations: [AIStreamCitationLabelDTO]?

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case finalText = "final_text"
        case citations
    }
}
