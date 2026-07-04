use maohuoban_ai_domain::ai::{
    AiChatSession, AiChatSessionStatus, AiConversationSurface, AiMessage, AiMessageRole,
    AiMessageStatus, AiSessionTurn, AiSessionTurnStatus,
};
use uuid::Uuid;

/// `session_id` 返回 Session/Turn 合同测试固定会话 ID
/// 核心职责：
/// - 固定测试中的 `session_id`
/// - 保持 turn、message 和 session 关联断言稳定
pub fn session_id() -> Uuid {
    Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("session id")
}

/// `actor_user_id` 返回 Session/Turn 合同测试固定用户 ID
/// 核心职责：
/// - 固定测试中的 `actor_user_id`
/// - 保持 session 与 turn 归属断言稳定
pub fn actor_user_id() -> Uuid {
    Uuid::parse_str("22222222-2222-2222-2222-222222222222").expect("actor user id")
}

/// `turn_id` 返回 Session/Turn 合同测试固定 Turn ID
/// 核心职责：
/// - 固定测试中的 `turn_id`
/// - 保持 replay 和状态更新断言稳定
pub fn turn_id() -> Uuid {
    Uuid::parse_str("33333333-3333-3333-3333-333333333333").expect("turn id")
}

/// `user_message_id` 返回固定用户消息 ID
/// 核心职责：
/// - 固定测试中的 `user_message_id`
/// - 保持 turn 与用户消息关联断言稳定
pub fn user_message_id() -> Uuid {
    Uuid::parse_str("44444444-4444-4444-4444-444444444444").expect("user message id")
}

/// `assistant_message_id` 返回固定助手消息 ID
/// 核心职责：
/// - 固定测试中的 `assistant_message_id`
/// - 保持 turn 与助手消息关联断言稳定
pub fn assistant_message_id() -> Uuid {
    Uuid::parse_str("55555555-5555-5555-5555-555555555555").expect("assistant message id")
}

/// `running_turn` 构造运行中的 Turn 夹具
/// 核心职责：
/// - 固定 Turn 账本默认字段
/// - 为 insert、update、list 合同测试提供基础数据
pub fn running_turn() -> AiSessionTurn {
    AiSessionTurn {
        id: turn_id(),
        session_id: session_id(),
        actor_user_id: actor_user_id(),
        user_message_id: user_message_id(),
        assistant_message_id: Some(assistant_message_id()),
        intent: "pet_care".to_owned(),
        gate_decision: "load_context".to_owned(),
        resolved_pet_id: None,
        engine_mode: "self_hosted".to_owned(),
        surface: AiConversationSurface::HomePrivate,
        status: AiSessionTurnStatus::Running,
        finish_reason: None,
        error_code: None,
        retryable: None,
        started_at: chrono::Utc::now(),
        finished_at: None,
    }
}

/// `user_message_with_turn` 构造带 Turn 关联的用户消息
/// 核心职责：
/// - 固定用户消息基础字段
/// - 验证 `message.turn_id` 与 session turn 的关联一致性
pub fn user_message_with_turn(turn: Uuid) -> AiMessage {
    AiMessage {
        id: user_message_id(),
        session_id: session_id(),
        turn_id: Some(turn),
        role: AiMessageRole::User,
        content: "豆包今天拉肚子怎么办".to_owned(),
        status: AiMessageStatus::Completed,
        citations: Vec::new(),
        content_blocks: Vec::new(),
        model: None,
        provider: None,
        finish_reason: None,
        usage_input_tokens: None,
        usage_output_tokens: None,
        verification: None,
        created_at: chrono::Utc::now(),
    }
}

/// `assistant_message_with_turn` 构造带 Turn 关联的助手消息
/// 核心职责：
/// - 固定助手消息基础字段
/// - 验证 assistant message 与 session turn 的关联一致性
pub fn assistant_message_with_turn(turn: Uuid) -> AiMessage {
    AiMessage {
        id: assistant_message_id(),
        session_id: session_id(),
        turn_id: Some(turn),
        role: AiMessageRole::Assistant,
        content: "先观察精神和食欲".to_owned(),
        status: AiMessageStatus::Completed,
        citations: Vec::new(),
        content_blocks: Vec::new(),
        model: Some("primary".to_owned()),
        provider: Some("self_hosted".to_owned()),
        finish_reason: Some("stop".to_owned()),
        usage_input_tokens: Some(10),
        usage_output_tokens: Some(5),
        verification: None,
        created_at: chrono::Utc::now(),
    }
}

/// `chat_session` 构造 AI 会话夹具
/// 核心职责：
/// - 固定会话基础字段
/// - 验证 session 与 turn 的 ID 和用户归属一致性
pub fn chat_session() -> AiChatSession {
    AiChatSession {
        id: session_id(),
        actor_user_id: actor_user_id(),
        primary_pet_id: None,
        surface: AiConversationSurface::HomePrivate,
        source_hint_id: None,
        source_task_id: None,
        title: "新对话".to_owned(),
        is_pinned: false,
        pet_display_snapshot: None,
        status: AiChatSessionStatus::Active,
        created_at: chrono::Utc::now(),
        updated_at: chrono::Utc::now(),
    }
}
