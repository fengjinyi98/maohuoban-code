import Foundation

// ChatStreamRequestBody 流式聊天请求体
// 核心职责：
// - 承载用户消息和入口上下文
// - 不包含 actor_user_id（只从 token 注入）
struct ChatStreamRequestBody: Encodable {
    let message: String
    let selectedPetID: String?
    let surface: String
    let chatSessionID: String?
    let chatContextKind: String?
    let abnormalEpisodeID: String?
    let sourceHintID: String?
    let agentFollowupID: String?

    enum CodingKeys: String, CodingKey {
        case message
        case selectedPetID = "selected_pet_id"
        case surface
        case chatSessionID = "chat_session_id"
        case chatContextKind = "chat_context_kind"
        case abnormalEpisodeID = "abnormal_episode_id"
        case sourceHintID = "source_hint_id"
        case agentFollowupID = "agent_followup_id"
    }
}
