import Foundation

// AIChatSessionDTO AI 会话列表项 DTO
// 核心职责：
// - 解码后端 GET /api/v1/ai/chat-sessions 返回的会话列表
// - 承载宠物展示快照和最近消息摘要
struct AIChatSessionDTO: Decodable {
    let id: UUID
    let title: String
    let subtitle: String
    let petDisplaySnapshot: AIPetDisplaySnapshotDTO?
    let lastMessagePreview: String
    let lastMessageAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case petDisplaySnapshot = "pet_display_snapshot"
        case lastMessagePreview = "last_message_preview"
        case lastMessageAt = "last_message_at"
    }
}

// AIPetDisplaySnapshotDTO 宠物展示快照 DTO
// 核心职责：
// - 解码后端返回的宠物展示快照
// - 只用于历史列表展示，不作为宠物事实来源
struct AIPetDisplaySnapshotDTO: Decodable {
    let petID: UUID
    let petName: String
    let petAvatarURL: String?
    let petSpecies: String
    let profileNumber: String

    enum CodingKeys: String, CodingKey {
        case petID = "pet_id"
        case petName = "pet_name"
        case petAvatarURL = "pet_avatar_url"
        case petSpecies = "pet_species"
        case profileNumber = "profile_number"
    }
}

// AIMessageDTO AI 消息 DTO
// 核心职责：
// - 解码后端 GET /api/v1/ai/chat-sessions/{id}/messages 返回的消息列表
// - 映射到前端 AIAssistantMessage
struct AIMessageDTO: Decodable {
    let id: UUID
    let role: String
    let content: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case createdAt = "created_at"
    }
}
