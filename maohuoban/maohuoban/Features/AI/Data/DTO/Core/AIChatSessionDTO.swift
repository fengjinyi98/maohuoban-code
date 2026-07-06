import Foundation

// AIChatSessionDTO AI 会话列表项 DTO
// 核心职责：
// - 解码后端 GET /api/v1/ai/chat-sessions 返回的会话列表
// - 承载宠物展示快照和最近消息摘要
struct AIChatSessionDTO: Decodable {
    let id: UUID
    let title: String
    let isPinned: Bool
    let chatContextKind: String?
    let abnormalEpisodeID: String?
    let sourceHintID: String?
    let agentFollowupID: String?
    let subtitle: String
    let petDisplaySnapshot: AIPetDisplaySnapshotDTO?
    let lastMessagePreview: String
    let lastMessageAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isPinned = "is_pinned"
        case chatContextKind = "chat_context_kind"
        case abnormalEpisodeID = "abnormal_episode_id"
        case sourceHintID = "source_hint_id"
        case agentFollowupID = "agent_followup_id"
        case subtitle
        case petDisplaySnapshot = "pet_display_snapshot"
        case lastMessagePreview = "last_message_preview"
        case lastMessageAt = "last_message_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        chatContextKind = try container.decodeIfPresent(String.self, forKey: .chatContextKind)
        abnormalEpisodeID = try container.decodeIfPresent(String.self, forKey: .abnormalEpisodeID)
        sourceHintID = try container.decodeIfPresent(String.self, forKey: .sourceHintID)
        agentFollowupID = try container.decodeIfPresent(String.self, forKey: .agentFollowupID)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        petDisplaySnapshot = try container.decodeIfPresent(AIPetDisplaySnapshotDTO.self, forKey: .petDisplaySnapshot)
        lastMessagePreview = try container.decode(String.self, forKey: .lastMessagePreview)
        lastMessageAt = try container.decode(String.self, forKey: .lastMessageAt)
    }
}

// AIChatSessionMutationResultDTO AI 会话操作结果 DTO
// 核心职责：
// - 解码后端重命名、置顶和删除接口返回的会话关键字段
// - 让 Store 使用服务端确认后的标题与置顶状态更新本地列表
struct AIChatSessionMutationResultDTO: Decodable, Equatable {
    let id: UUID
    let title: String
    let isPinned: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isPinned = "is_pinned"
    }
}

// AIAbnormalEpisodeSessionActivationRequestBody 异常追踪会话激活请求
// 核心职责：
// - 承载从轻提醒进入 AI 聊天时的 abnormal episode ID
// - 让后端把后台追踪上下文升级为用户可见会话
struct AIAbnormalEpisodeSessionActivationRequestBody: Encodable {
    let abnormalEpisodeID: String

    enum CodingKeys: String, CodingKey {
        case abnormalEpisodeID = "abnormal_episode_id"
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
    let contentBlocks: [AIAssistantContentBlock]
    let citations: [AIMessageCitationDTO]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case contentBlocks = "content_blocks"
        case citations
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(String.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        contentBlocks = try container.decodeIfPresent([AIAssistantContentBlock].self, forKey: .contentBlocks) ?? []
        citations = try container.decodeIfPresent([AIMessageCitationDTO].self, forKey: .citations) ?? []
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }
}

// AIMessageCitationDTO AI 历史消息引用 DTO
// 核心职责：
// - 解码历史消息中的引用来源明细
// - 映射为前端结构化引用模型
struct AIMessageCitationDTO: Decodable, Hashable {
    let sourceKind: String
    let sourceID: UUID
    let label: String

    enum CodingKeys: String, CodingKey {
        case sourceKind = "source_kind"
        case sourceID = "source_id"
        case label
    }

    var reference: AIAssistantReference {
        AIAssistantReference(
            sourceKind: sourceKind,
            sourceID: sourceID,
            label: label
        )
    }
}
