// session_summary 会话摘要压缩测试
// 核心职责：
// - 验证 CompressionThreshold 评估触发条件（含 LongSessionResumed）
// - 验证 SessionSummary 安全前缀和压缩边界
// - 验证 SessionSummaryCompressor 压缩流程（投影后送 LLM、持久化边界）
// - 验证压缩后保留尾部消息和摘要写入
//
// MHB_STRUCTURE_EXEMPTION: session summary compressor contract 保持单入口，domain 阈值、压缩流程和 fake repository/provider 共用同一组消息 fixture；拆散会增加重复测试夹具。

use std::future::Future;
use std::pin::Pin;

use futures_util::stream::BoxStream;
use maohuoban_ai_application::ai::ports::{FakeLlmProvider, LlmProvider, SessionSummaryRepository};
use maohuoban_ai_application::ai::session_summary::{CompressedHistory, SessionSummaryCompressor};
use maohuoban_ai_domain::ai::{
    AiMessage, AiMessageRole, AiMessageStatus, AiResult, CompressionThreshold, CompressionTrigger,
    LlmChatResponse, LlmFinishReason, LlmStreamEvent, LlmUsage, SessionSummary,
    SessionSummaryScope,
};
use std::sync::{Arc, Mutex};
use uuid::Uuid;

fn session_id() -> Uuid {
    Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("session id")
}

fn actor_user_id() -> Uuid {
    Uuid::parse_str("22222222-2222-2222-2222-222222222222").expect("actor user id")
}

fn user_message(content: &str, ts: i64) -> AiMessage {
    AiMessage {
        id: Uuid::new_v4(),
        session_id: session_id(),
        turn_id: None,
        role: AiMessageRole::User,
        content: content.to_owned(),
        status: AiMessageStatus::Completed,
        citations: Vec::new(),
        model: None,
        provider: None,
        finish_reason: None,
        usage_input_tokens: None,
        usage_output_tokens: None,
        verification: None,
        created_at: chrono::DateTime::from_timestamp(ts, 0).expect("ts"),
    }
}

fn user_message_with_id(id: Uuid, content: &str, ts: i64) -> AiMessage {
    AiMessage {
        id,
        session_id: session_id(),
        turn_id: None,
        role: AiMessageRole::User,
        content: content.to_owned(),
        status: AiMessageStatus::Completed,
        citations: Vec::new(),
        model: None,
        provider: None,
        finish_reason: None,
        usage_input_tokens: None,
        usage_output_tokens: None,
        verification: None,
        created_at: chrono::DateTime::from_timestamp(ts, 0).expect("ts"),
    }
}

fn assistant_message(content: &str, ts: i64) -> AiMessage {
    AiMessage {
        id: Uuid::new_v4(),
        session_id: session_id(),
        turn_id: None,
        role: AiMessageRole::Assistant,
        content: content.to_owned(),
        status: AiMessageStatus::Completed,
        citations: Vec::new(),
        model: Some("primary".to_owned()),
        provider: Some("scripted".to_owned()),
        finish_reason: Some("stop".to_owned()),
        usage_input_tokens: Some(10),
        usage_output_tokens: Some(5),
        verification: None,
        created_at: chrono::DateTime::from_timestamp(ts, 0).expect("ts"),
    }
}

fn fake_llm(summary_text: &str) -> FakeLlmProvider {
    FakeLlmProvider::new(
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
        },
        Vec::<LlmStreamEvent>::new(),
    )
}

fn sample_summary() -> SessionSummary {
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

// === Domain 层测试 ===

#[test]
fn compression_threshold_no_trigger_when_below_limits() {
    let threshold = CompressionThreshold::new(10, 10_000);
    assert!(threshold.should_compress(5, 1_000, None).is_none());
}

#[test]
fn compression_threshold_triggers_on_message_count() {
    let threshold = CompressionThreshold::new(10, 100_000);
    let trigger = threshold.should_compress(15, 1_000, None);
    assert_eq!(trigger, Some(CompressionTrigger::MessageCountExceeded));
}

#[test]
fn compression_threshold_triggers_on_budget_first() {
    let threshold = CompressionThreshold::new(100, 10_000);
    let trigger = threshold.should_compress(50, 12_000, None);
    assert_eq!(trigger, Some(CompressionTrigger::BudgetThresholdApproached));
}

#[test]
fn compression_threshold_triggers_on_long_session_resumed() {
    let threshold = CompressionThreshold::new(100, 100_000);
    // 最后一条消息距今 10 天，超过 resume_after_days=7
    let trigger = threshold.should_compress(5, 1_000, Some(10));
    assert_eq!(trigger, Some(CompressionTrigger::LongSessionResumed));
}

#[test]
fn compression_threshold_no_resume_trigger_when_within_days() {
    let threshold = CompressionThreshold::new(100, 100_000);
    let trigger = threshold.should_compress(5, 1_000, Some(3));
    assert!(trigger.is_none());
}

#[test]
fn compression_threshold_no_resume_trigger_when_no_messages() {
    let threshold = CompressionThreshold::new(100, 100_000);
    let trigger = threshold.should_compress(0, 0, Some(10));
    assert!(trigger.is_none());
}

#[test]
fn session_summary_to_context_adds_safety_prefix() {
    let summary = SessionSummary {
        summary_text: "用户养了一只叫豆包的猫，最近在讨论腹泻问题。".to_owned(),
        ..sample_summary()
    };

    let context = summary.to_context_summary();
    assert!(context.contains("【历史参考"));
    assert!(context.contains("不激活旧任务"));
    assert!(context.contains("豆包"));
}

#[test]
fn session_summary_is_active_when_not_superseded() {
    let summary = sample_summary();
    assert!(summary.is_active());

    let superseded = SessionSummary {
        superseded_at: Some(chrono::Utc::now()),
        ..summary
    };
    assert!(!superseded.is_active());
}

#[test]
fn session_summary_covers_message_by_boundary() {
    let boundary_id = Uuid::new_v4();
    let created_at = chrono::Utc::now();
    let summary = SessionSummary {
        compressed_until_message_id: Some(boundary_id),
        created_at,
        ..sample_summary()
    };

    // 消息创建时间 <= 摘要创建时间 => 被覆盖
    assert!(summary.covers_message(created_at));
    assert!(summary.covers_message(chrono::DateTime::from_timestamp(1, 0).expect("ts")));
}

#[test]
fn session_summary_no_boundary_does_not_cover() {
    let summary = sample_summary();
    assert!(!summary.covers_message(chrono::Utc::now()));
}

// === Application 层测试 ===

#[tokio::test]
async fn compressor_returns_none_when_below_threshold() {
    let llm = Arc::new(fake_llm("summary"));
    let repo = Arc::new(InMemorySummaryRepo::new());
    let compressor = SessionSummaryCompressor::new(llm, repo);

    let messages = vec![
        user_message("你好", 1),
        assistant_message("你好，有什么可以帮你的？", 2),
    ];

    let result = compressor
        .try_compress(session_id(), actor_user_id(), &messages, 3, None)
        .await
        .expect("compress");

    assert!(result.is_none());
}

#[tokio::test]
async fn compressor_generates_summary_and_retains_tail() {
    let llm = Arc::new(fake_llm(
        "用户养了一只叫豆包的猫，讨论了腹泻和饮食调整，建议观察24小时。",
    ));
    let repo = Arc::new(InMemorySummaryRepo::new());
    let compressor = SessionSummaryCompressor::new(llm, repo.clone());

    // 构造超过阈值的历史（40+ 条消息）
    let mut messages = Vec::new();
    for i in 0..50 {
        messages.push(user_message(&format!("用户消息{i}"), i64::from(i)));
        messages.push(assistant_message(&format!("助手回复{i}"), i64::from(i) + 1));
    }

    let result = compressor
        .try_compress(session_id(), actor_user_id(), &messages, 3, None)
        .await
        .expect("compress");

    let compressed = result.expect("should compress");
    assert_eq!(compressed.retained_tail.entries.len(), 6);
    assert!(!compressed.summary.summary_text.is_empty());
    assert!(compressed.summary.is_active());

    // 验证摘要已写入仓储
    let active = repo
        .get_active_summary(session_id())
        .await
        .expect("get active");
    assert!(active.is_some());
    let active = active.expect("active summary");
    assert_eq!(active.summary_text, compressed.summary.summary_text);
}

#[tokio::test]
async fn compressor_persists_compression_boundary() {
    let llm = Arc::new(fake_llm("摘要内容"));
    let repo = Arc::new(InMemorySummaryRepo::new());
    let compressor = SessionSummaryCompressor::new(llm, repo.clone());

    let mut messages = Vec::new();
    for i in 0..50 {
        messages.push(user_message(&format!("msg{i}"), i64::from(i)));
        messages.push(assistant_message(&format!("reply{i}"), i64::from(i) + 1));
    }

    let result = compressor
        .try_compress(session_id(), actor_user_id(), &messages, 3, None)
        .await
        .expect("compress");

    let compressed = result.expect("should compress");

    // 压缩边界应该是被压缩的最后一条消息的 ID
    let expected_boundary = messages[messages.len() - 6 - 1].id;
    assert_eq!(
        compressed.summary.compressed_until_message_id,
        Some(expected_boundary)
    );

    // 仓储中的摘要也应该有压缩边界
    let active = repo
        .get_active_summary(session_id())
        .await
        .expect("get active")
        .expect("active summary");
    assert_eq!(active.compressed_until_message_id, Some(expected_boundary));
}

#[tokio::test]
async fn compressor_strips_internal_fields_before_llm() {
    // 使用一个能记录收到的 LLM 请求内容的 fake provider
    let captured_request = Arc::new(Mutex::new(None::<String>));
    let llm = Arc::new(CapturingLlmProvider::new("摘要", captured_request.clone()));
    let repo = Arc::new(InMemorySummaryRepo::new());
    let compressor = SessionSummaryCompressor::new(llm, repo);

    let mut messages = Vec::new();
    for i in 0..50 {
        messages.push(user_message(&format!("msg{i}"), i64::from(i)));
        messages.push(assistant_message(&format!("reply{i}"), i64::from(i) + 1));
    }

    compressor
        .try_compress(session_id(), actor_user_id(), &messages, 3, None)
        .await
        .expect("compress");

    let captured = captured_request
        .lock()
        .expect("lock")
        .clone()
        .expect("captured");
    // 检查 assistant 消息中的内部字段值不会出现在 LLM 输入中
    // "scripted" 是 provider 字段值，"primary" 是 model 字段值
    // 这两个词不会出现在消息内容中，如果出现说明投影未生效
    for forbidden in ["scripted", "primary"] {
        assert!(
            !captured.contains(forbidden),
            "LLM input must not contain forbidden internal value {forbidden}: {captured}"
        );
    }
}

#[tokio::test]
async fn compressor_summary_contains_safety_prefix_when_injected() {
    let llm = Arc::new(fake_llm("用户养了一只叫豆包的猫。"));
    let repo = Arc::new(InMemorySummaryRepo::new());
    let compressor = SessionSummaryCompressor::new(llm, repo);

    let mut messages = Vec::new();
    for i in 0..50 {
        messages.push(user_message(&format!("msg{i}"), i64::from(i)));
        messages.push(assistant_message(&format!("reply{i}"), i64::from(i) + 1));
    }

    let result = compressor
        .try_compress(session_id(), actor_user_id(), &messages, 3, None)
        .await
        .expect("compress");

    let compressed: CompressedHistory = result.expect("should compress");
    let context_text = compressed.summary.to_context_summary();
    assert!(context_text.starts_with("【历史参考"));
    assert!(context_text.contains("不激活旧任务"));
}

#[tokio::test]
async fn compressor_supersedes_previous_summaries() {
    let llm = Arc::new(fake_llm("第二次摘要"));
    let repo = Arc::new(InMemorySummaryRepo::new());
    let compressor = SessionSummaryCompressor::new(llm, repo.clone());

    let mut messages = Vec::new();
    for i in 0..50 {
        messages.push(user_message(&format!("msg{i}"), i64::from(i)));
        messages.push(assistant_message(&format!("reply{i}"), i64::from(i) + 1));
    }

    // 第一次压缩
    let first = compressor
        .try_compress(session_id(), actor_user_id(), &messages, 3, None)
        .await
        .expect("compress");
    assert!(first.is_some());

    // 第二次压缩
    let second = compressor
        .try_compress(session_id(), actor_user_id(), &messages, 3, None)
        .await
        .expect("compress");
    let second = second.expect("second compress");

    // 验证旧摘要已被替代
    let active = repo
        .get_active_summary(session_id())
        .await
        .expect("get active");
    assert!(active.is_some());
    let active = active.expect("active");
    assert_eq!(active.summary_text, "第二次摘要");
    assert_eq!(active.id, second.summary.id);
}

#[tokio::test]
async fn compressor_loads_active_summary() {
    let llm = Arc::new(fake_llm("summary"));
    let repo = Arc::new(InMemorySummaryRepo::new());
    let compressor = SessionSummaryCompressor::new(llm, repo.clone());

    // 手动写入一个摘要
    let summary = sample_summary();
    repo.insert_summary(&summary).await.expect("insert");

    let loaded = compressor
        .load_active_summary(session_id())
        .await
        .expect("load");
    assert!(loaded.is_some());
    assert_eq!(loaded.expect("loaded").summary_text, "test");
}

#[tokio::test]
async fn compressor_triggers_on_long_session_resumed() {
    let llm = Arc::new(fake_llm("恢复旧会话摘要"));
    let repo = Arc::new(InMemorySummaryRepo::new());
    let compressor = SessionSummaryCompressor::new(llm, repo.clone());

    // 构造少量但很旧的消息（5条，最后一条在 10 天前）
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

    let result = compressor
        .try_compress(session_id(), actor_user_id(), &messages, 2, None)
        .await
        .expect("compress");

    // 应该因为 LongSessionResumed 触发压缩
    let compressed = result.expect("should compress on resume");
    assert_eq!(compressed.retained_tail.entries.len(), 4);
    assert!(!compressed.summary.summary_text.is_empty());
}

#[tokio::test]
async fn compressor_triggers_resume_when_current_message_just_written() {
    // 模拟真实 HTTP 时序：当前用户消息已持久化到 messages 末尾，
    // 但上一轮历史消息很旧。exclude_message_id 排除当前消息后，
    // resume age 应基于上一轮消息计算，从而触发 LongSessionResumed。
    let llm = Arc::new(fake_llm("恢复旧会话摘要"));
    let repo = Arc::new(InMemorySummaryRepo::new());
    let compressor = SessionSummaryCompressor::new(llm, repo.clone());

    // 旧消息：10 天前的对话
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

    // 当前轮用户消息刚写入（age ≈ 0），模拟真实持久化后调用 try_compress
    let current_message_id = Uuid::new_v4();
    messages.push(user_message_with_id(
        current_message_id,
        "继续上次的话题",
        chrono::Utc::now().timestamp(),
    ));

    let result = compressor
        .try_compress(
            session_id(),
            actor_user_id(),
            &messages,
            2,
            Some(current_message_id),
        )
        .await
        .expect("compress");

    // 排除当前消息后，最后一条历史消息是 10 天前的，应触发 LongSessionResumed
    let compressed = result.expect("should trigger on resume despite current message");
    assert!(!compressed.summary.summary_text.is_empty());
}

#[tokio::test]
async fn compressor_no_resume_when_exclude_makes_history_empty() {
    // 只有当前轮一条消息，排除后历史为空，不应触发压缩
    let llm = Arc::new(fake_llm("不应触发"));
    let repo = Arc::new(InMemorySummaryRepo::new());
    let compressor = SessionSummaryCompressor::new(llm, repo);

    let current_message_id = Uuid::new_v4();
    let messages = vec![user_message_with_id(
        current_message_id,
        "第一条消息",
        chrono::Utc::now().timestamp(),
    )];

    let result = compressor
        .try_compress(
            session_id(),
            actor_user_id(),
            &messages,
            2,
            Some(current_message_id),
        )
        .await
        .expect("compress");

    assert!(result.is_none());
}

#[tokio::test]
async fn compressor_retained_tail_excludes_current_message() {
    // 模拟真实 HTTP 时序：当前用户消息已持久化到 messages 末尾，
    // 触发压缩时 retained_tail 不应包含当前轮消息。
    let llm = Arc::new(fake_llm("摘要"));
    let repo = Arc::new(InMemorySummaryRepo::new());
    let compressor = SessionSummaryCompressor::new(llm, repo);

    // 构造超过阈值的历史
    let mut messages = Vec::new();
    for i in 0..50 {
        messages.push(user_message(&format!("msg{i}"), i64::from(i)));
        messages.push(assistant_message(&format!("reply{i}"), i64::from(i) + 1));
    }

    // 当前轮用户消息追加到末尾
    let current_message_id = Uuid::new_v4();
    messages.push(user_message_with_id(current_message_id, "当前轮问题", 100));

    let result = compressor
        .try_compress(
            session_id(),
            actor_user_id(),
            &messages,
            3,
            Some(current_message_id),
        )
        .await
        .expect("compress");

    let compressed = result.expect("should compress");

    // retained_tail 不应包含当前轮消息内容
    for entry in &compressed.retained_tail.entries {
        assert_ne!(
            entry.content, "当前轮问题",
            "retained_tail must not contain current turn message"
        );
    }
}

#[tokio::test]
async fn compressor_retained_tail_excludes_current_message_on_resume() {
    // 模拟旧会话恢复：历史消息很旧，当前消息刚写入，
    // 触发 LongSessionResumed 时 retained_tail 也不应包含当前轮消息。
    let llm = Arc::new(fake_llm("恢复摘要"));
    let repo = Arc::new(InMemorySummaryRepo::new());
    let compressor = SessionSummaryCompressor::new(llm, repo);

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

    let current_message_id = Uuid::new_v4();
    messages.push(user_message_with_id(
        current_message_id,
        "继续上次话题",
        chrono::Utc::now().timestamp(),
    ));

    let result = compressor
        .try_compress(
            session_id(),
            actor_user_id(),
            &messages,
            2,
            Some(current_message_id),
        )
        .await
        .expect("compress");

    let compressed = result.expect("should trigger on resume");

    // retained_tail 不应包含当前轮消息内容
    for entry in &compressed.retained_tail.entries {
        assert_ne!(
            entry.content, "继续上次话题",
            "retained_tail must not contain current turn message on resume"
        );
    }
}

// === Fake 实现 ===

struct InMemorySummaryRepo {
    summaries: Mutex<Vec<SessionSummary>>,
}

impl InMemorySummaryRepo {
    fn new() -> Self {
        Self {
            summaries: Mutex::new(Vec::new()),
        }
    }
}

#[async_trait::async_trait]
impl SessionSummaryRepository for InMemorySummaryRepo {
    async fn insert_summary(&self, summary: &SessionSummary) -> AiResult<()> {
        self.summaries.lock().expect("lock").push(summary.clone());
        Ok(())
    }

    async fn get_active_summary(&self, chat_session_id: Uuid) -> AiResult<Option<SessionSummary>> {
        let summaries = self.summaries.lock().expect("lock");
        Ok(summaries
            .iter()
            .rfind(|s| s.chat_session_id == chat_session_id && s.is_active())
            .cloned())
    }

    async fn supersede_previous_summaries(
        &self,
        chat_session_id: Uuid,
        superseded_at: chrono::DateTime<chrono::Utc>,
    ) -> AiResult<()> {
        let mut summaries = self.summaries.lock().expect("lock");
        for s in summaries.iter_mut() {
            if s.chat_session_id == chat_session_id && s.is_active() {
                s.superseded_at = Some(superseded_at);
            }
        }
        Ok(())
    }
}

/// `CapturingLlmProvider` 捕获 LLM 请求内容的 fake provider
/// 核心职责：
/// - 记录收到的 LLM 请求文本，用于验证内部字段是否被过滤
struct CapturingLlmProvider {
    response: LlmChatResponse,
    captured: Arc<Mutex<Option<String>>>,
}

impl CapturingLlmProvider {
    fn new(summary_text: &str, captured: Arc<Mutex<Option<String>>>) -> Self {
        Self {
            response: LlmChatResponse {
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
            },
            captured,
        }
    }
}

impl LlmProvider for CapturingLlmProvider {
    fn complete<'a>(
        &'a self,
        request: &'a maohuoban_ai_domain::ai::LlmChatRequest,
    ) -> Pin<Box<dyn Future<Output = AiResult<LlmChatResponse>> + Send + 'a>> {
        let captured = self.captured.clone();
        let response = self.response.clone();
        Box::pin(async move {
            let text = request
                .messages
                .iter()
                .map(|m| m.content.as_str())
                .collect::<Vec<_>>()
                .join("\n");
            *captured.lock().expect("lock") = Some(text);
            Ok(response)
        })
    }

    fn stream<'a>(
        &'a self,
        _request: &'a maohuoban_ai_domain::ai::LlmChatRequest,
    ) -> BoxStream<'a, AiResult<LlmStreamEvent>> {
        Box::pin(futures_util::stream::empty())
    }
}
