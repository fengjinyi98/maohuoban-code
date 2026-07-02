import Foundation

struct AIStreamMessageCompletedPayload: Decodable {
    let messageID: UUID
    let finalText: String
    let contentBlocks: [AIAssistantContentBlock]?
    let citations: [AIStreamCitationLabelDTO]?

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case finalText = "final_text"
        case contentBlocks = "content_blocks"
        case citations
    }
}
