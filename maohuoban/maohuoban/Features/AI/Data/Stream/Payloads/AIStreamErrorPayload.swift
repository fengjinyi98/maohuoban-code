import Foundation

struct AIStreamErrorPayload: Decodable {
    let code: String
    let message: String
    let retryable: Bool
    let safeFallbackText: String?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case retryable
        case safeFallbackText = "safe_fallback_text"
    }
}
