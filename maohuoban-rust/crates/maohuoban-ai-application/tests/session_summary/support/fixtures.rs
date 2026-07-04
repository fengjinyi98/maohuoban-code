use maohuoban_ai_application::ai::ports::FakeLlmProvider;
use maohuoban_ai_domain::ai::{
    AiMessage, AiMessageRole, AiMessageStatus, LlmChatResponse, LlmFinishReason, LlmStreamEvent,
    LlmUsage, SessionSummary, SessionSummaryScope,
};
use uuid::Uuid;

/// `session_id` 返回会话摘要合同测试固定会话 ID
/// 核心职责：
/// - 固定测试中的 `chat_session_id`
/// - 保持摘要、消息和压缩边界断言稳定
pub fn session_id() -> Uuid {
    Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("session id")
}

/// `actor_user_id` 返回会话摘要合同测试固定用户 ID
/// 核心职责：
/// - 固定测试中的 `actor_user_id`
/// - 保持摘要 scope 归属断言稳定
pub fn actor_user_id() -> Uuid {
    Uuid::parse_str("22222222-2222-2222-2222-222222222222").expect("actor user id")
}

/// `user_message` 构造用户消息夹具
/// 核心职责：
/// - 固定用户消息默认字段
/// - 通过时间戳控制压缩和恢复测试顺序
pub fn user_message(content: &str, ts: i64) -> AiMessage {
    AiMessage {
        id: Uuid::new_v4(),
        session_id: session_id(),
        turn_id: None,
        role: AiMessageRole::User,
        content: content.to_owned(),
        status: AiMessageStatus::Completed,
        citations: Vec::new(),
        content_blocks: Vec::new(),
        model: None,
        provider: None,
        finish_reason: None,
        usage_input_tokens: None,
        usage_output_tokens: None,
        verification: None,
        created_at: chrono::DateTime::from_timestamp(ts, 0).expect("ts"),
    }
}

/// `user_message_with_id` 构造指定 ID 的用户消息夹具
/// 核心职责：
/// - 固定当前轮消息 ID
/// - 验证压缩排除当前轮消息的边界行为
pub fn user_message_with_id(id: Uuid, content: &str, ts: i64) -> AiMessage {
    AiMessage {
        id,
        session_id: session_id(),
        turn_id: None,
        role: AiMessageRole::User,
        content: content.to_owned(),
        status: AiMessageStatus::Completed,
        citations: Vec::new(),
        content_blocks: Vec::new(),
        model: None,
        provider: None,
        finish_reason: None,
        usage_input_tokens: None,
        usage_output_tokens: None,
        verification: None,
        created_at: chrono::DateTime::from_timestamp(ts, 0).expect("ts"),
    }
}

/// `assistant_message` 构造助手消息夹具
/// 核心职责：
/// - 固定助手消息内部 provider/model 字段
/// - 为投影过滤测试提供可检测内部字段
pub fn assistant_message(content: &str, ts: i64) -> AiMessage {
    AiMessage {
        id: Uuid::new_v4(),
        session_id: session_id(),
        turn_id: None,
        role: AiMessageRole::Assistant,
        content: content.to_owned(),
        status: AiMessageStatus::Completed,
        citations: Vec::new(),
        content_blocks: Vec::new(),
        model: Some("primary".to_owned()),
        provider: Some("scripted".to_owned()),
        finish_reason: Some("stop".to_owned()),
        usage_input_tokens: Some(10),
        usage_output_tokens: Some(5),
        verification: None,
        created_at: chrono::DateTime::from_timestamp(ts, 0).expect("ts"),
    }
}

/// `long_message_history` 构造超过摘要阈值的长历史
/// 核心职责：
/// - 固定 50 轮用户和助手消息
/// - 为消息数触发压缩测试提供可复用历史
pub fn long_message_history(user_prefix: &str, assistant_prefix: &str) -> Vec<AiMessage> {
    let mut messages = Vec::new();
    for i in 0..50 {
        messages.push(user_message(&format!("{user_prefix}{i}"), i64::from(i)));
        messages.push(assistant_message(
            &format!("{assistant_prefix}{i}"),
            i64::from(i) + 1,
        ));
    }
    messages
}

/// `old_message_history` 构造旧会话恢复历史
/// 核心职责：
/// - 固定 10 天前的 5 轮历史消息
/// - 为 `LongSessionResumed` 触发测试提供可复用历史
pub fn old_message_history() -> Vec<AiMessage> {
    let old_ts = chrono::Utc::now().timestamp() - 10 * 24 * 3600;
    let mut messages = Vec::new();
    for i in 0..5 {
        messages.push(user_message_with_id(
            Uuid::new_v4(),
            &format!("旧消息{i}"),
            old_ts + i * 60,
        ));
        messages.push(assistant_message(
            &format!("旧回复{i}"),
            old_ts + i * 60 + 30,
        ));
    }
    messages
}

/// `fake_llm` 构造固定摘要响应的 LLM provider
/// 核心职责：
/// - 固定非流式摘要响应
/// - 为压缩流程测试隔离外部 provider
pub fn fake_llm(summary_text: &str) -> FakeLlmProvider {
    FakeLlmProvider::new(
        fake_llm_response(summary_text),
        Vec::<LlmStreamEvent>::new(),
    )
}

/// `fake_llm_response` 构造固定 LLM 摘要响应
/// 核心职责：
/// - 固定响应 usage、finish reason、provider 和 model
/// - 复用在普通 fake 与捕获型 fake provider 中
pub fn fake_llm_response(summary_text: &str) -> LlmChatResponse {
    LlmChatResponse {
        message: maohuoban_ai_domain::ai::LlmMessage {
            role: maohuoban_ai_domain::ai::LlmRole::Assistant,
            content: summary_text.to_owned(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: Vec::new(),
        usage: LlmUsage {
            input_tokens: 100,
            output_tokens: 50,
            total_tokens: 150,
        },
        finish_reason: LlmFinishReason::Stop,
        provider: "fake".to_owned(),
        model: "fake-model".to_owned(),
    }
}

/// `sample_summary` 构造会话摘要夹具
/// 核心职责：
/// - 固定摘要基础字段
/// - 为 domain 和 repository 合同测试提供默认摘要
pub fn sample_summary() -> SessionSummary {
    SessionSummary {
        id: Uuid::new_v4(),
        chat_session_id: session_id(),
        scope_type: SessionSummaryScope::User,
        scope_id: actor_user_id(),
        summary_text: "test".to_owned(),
        referenced_event_ids: Vec::new(),
        token_budget_hint: None,
        compressed_until_message_id: None,
        created_at: chrono::Utc::now(),
        superseded_at: None,
    }
}
