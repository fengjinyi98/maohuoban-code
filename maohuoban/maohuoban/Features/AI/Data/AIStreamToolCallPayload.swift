import Foundation

struct AIStreamToolCallPayload: Decodable {
    let toolName: String
    let status: String
    let citationCount: Int

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case status
        case citationCount = "citation_count"
    }
}
