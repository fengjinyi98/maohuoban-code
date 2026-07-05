// conversation_history 同会话历史连续性测试
// 核心职责：
// - 验证 Loader 校验会话归属后加载历史
// - 验证 Loader 按 exclude_message_id 排除当前轮用户消息
// - 验证 Projector 从 AiMessage 投影时丢弃 provider/model/usage 等内部字段
// - 验证 TurnContextBuilder 可接收同会话最近历史
// - 验证 ContextBudgetPolicy 按预算裁剪

use maohuoban_ai_application::ai::conversation_history::{
    ConversationHistoryProjector, RecentConversationLoader, RecentConversationPack,
};
use maohuoban_ai_application::ai::ports::{AiSessionRepository, NoopSessionSummaryRepository};
use maohuoban_ai_application::ai::turn_context::{ContextBudgetPolicy, TurnContextBuilder};
use maohuoban_ai_domain::ai::{
    AiChatSession, AiChatSessionStatus, AiCitation, AiConversationSurface, AiMessage,
    AiMessageRole, AiMessageStatus, RecentConversationEntry,
};
use std::sync::Arc;
use uuid::Uuid;

fn session_id() -> Uuid {
    Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("session id")
}

fn actor_user_id() -> Uuid {
    Uuid::parse_str("22222222-2222-2222-2222-222222222222").expect("actor user id")
}

fn other_user_id() -> Uuid {
    Uuid::parse_str("33333333-3333-3333-3333-333333333333").expect("other user id")
}

fn user_message(content: &str, created_at: i64) -> AiMessage {
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
        created_at: chrono::DateTime::from_timestamp(created_at, 0).expect("timestamp"),
    }
}

fn user_message_with_id(id: Uuid, content: &str, created_at: i64) -> AiMessage {
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
        created_at: chrono::DateTime::from_timestamp(created_at, 0).expect("timestamp"),
    }
}

fn assistant_message(content: &str, created_at: i64) -> AiMessage {
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
        created_at: chrono::DateTime::from_timestamp(created_at, 0).expect("timestamp"),
    }
}

#[tokio::test]
async fn loader_excludes_current_message_by_id() {
    let current_msg_id = Uuid::new_v4();
    let repo = Arc::new(FakeSessionRepository::new(
        vec![
            user_message("第一轮用户问题", 1),
            assistant_message("第一轮助手回答", 2),
            user_message_with_id(current_msg_id, "第二轮追问", 3),
        ],
        actor_user_id(),
    ));

    let loader = RecentConversationLoader::new(repo, Arc::new(NoopSessionSummaryRepository));
    let pack = loader
        .load_recent_conversation(actor_user_id(), session_id(), current_msg_id, 32_000, 2_048)
        .await
        .expect("load history");

    assert_eq!(pack.entries.len(), 2);
    assert_eq!(pack.entries[0].role, AiMessageRole::User);
    assert_eq!(pack.entries[0].content, "第一轮用户问题");
    assert_eq!(pack.entries[1].role, AiMessageRole::Assistant);
    assert_eq!(pack.entries[1].content, "第一轮助手回答");
}

#[tokio::test]
async fn loader_applies_explicit_recent_conversation_budget() {
    let current_msg_id = Uuid::new_v4();
    let repo = Arc::new(FakeSessionRepository::new(
        vec![
            user_message("第一轮用户问题", 1),
            assistant_message("第一轮助手回答", 2),
            user_message("第二轮用户问题", 3),
            assistant_message("第二轮助手回答", 4),
            user_message_with_id(current_msg_id, "第三轮追问", 5),
        ],
        actor_user_id(),
    ));

    let loader = RecentConversationLoader::new(repo, Arc::new(NoopSessionSummaryRepository));
    let pack = loader
        .load_recent_conversation(actor_user_id(), session_id(), current_msg_id, 1, 10_000)
        .await
        .expect("load history");

    assert_eq!(pack.entries.len(), 2);
    assert_eq!(pack.entries[0].content, "第二轮用户问题");
    assert_eq!(pack.entries[1].content, "第二轮助手回答");
}

#[tokio::test]
async fn loader_rejects_session_not_belonging_to_actor() {
    let repo = Arc::new(FakeSessionRepository::new(
        vec![user_message("test", 1)],
        other_user_id(),
    ));

    let loader = RecentConversationLoader::new(repo, Arc::new(NoopSessionSummaryRepository));
    let result = loader
        .load_recent_conversation(actor_user_id(), session_id(), Uuid::new_v4(), 32_000, 2_048)
        .await;

    assert!(
        result.is_err(),
        "loader must reject session not belonging to actor"
    );
}

#[tokio::test]
async fn loader_rejects_missing_session() {
    let repo = Arc::new(FakeSessionRepository::new(vec![], actor_user_id()));
    let loader = RecentConversationLoader::new(repo, Arc::new(NoopSessionSummaryRepository));
    let result = loader
        .load_recent_conversation(
            actor_user_id(),
            Uuid::new_v4(),
            Uuid::new_v4(),
            32_000,
            2_048,
        )
        .await;

    assert!(result.is_err(), "loader must reject missing session");
}

#[test]
fn projector_strips_internal_fields_from_persisted_messages() {
    let messages = vec![
        user_message("豆包今天拉肚子怎么办", 1),
        assistant_message("先观察精神和食欲", 2),
    ];

    let pack = ConversationHistoryProjector::new().project_messages(&messages);
    let request_json = serde_json::to_string(&pack).expect("serialize request");

    assert!(request_json.contains("豆包今天拉肚子怎么办"));
    assert!(request_json.contains("先观察精神和食欲"));

    // AiMessage 的内部字段不应出现在投影结果中
    for forbidden in [
        "provider",
        "model",
        "finish_reason",
        "usage_input_tokens",
        "usage_output_tokens",
        "verification",
        "citations",
        "status",
        "scripted",
        "primary",
    ] {
        assert!(
            !request_json.contains(forbidden),
            "projected history must not contain forbidden field {forbidden}: {request_json}"
        );
    }
}

#[test]
fn turn_context_builder_accepts_recent_history_pack() {
    let workbench = TurnContextBuilder::new(AiConversationSurface::HomePrivate)
        .with_recent_conversation(RecentConversationPack {
            entries: vec![RecentConversationEntry {
                role: AiMessageRole::User,
                content: "第一轮用户问题".to_owned(),
                tool_call_id: None,
                tool_calls: Vec::new(),
            }],
        })
        .build();

    assert!(workbench.recent_conversation_pack.is_some());
    assert_eq!(
        workbench
            .recent_conversation_pack
            .as_ref()
            .expect("recent history")
            .entries
            .len(),
        1
    );
}

fn history_entry(role: AiMessageRole, content: &str) -> RecentConversationEntry {
    RecentConversationEntry {
        role,
        content: content.to_owned(),
        tool_call_id: None,
        tool_calls: Vec::new(),
    }
}

#[test]
fn context_budget_policy_keeps_all_when_within_budget() {
    let pack = RecentConversationPack {
        entries: vec![
            history_entry(AiMessageRole::User, "turn1 user"),
            history_entry(AiMessageRole::Assistant, "turn1 assistant"),
            history_entry(AiMessageRole::User, "turn2 user"),
            history_entry(AiMessageRole::Assistant, "turn2 assistant"),
        ],
    };

    let policy = ContextBudgetPolicy::new(10, 100_000);
    let trimmed = policy.trim(&pack);

    assert_eq!(trimmed.entries.len(), 4);
}

#[test]
fn context_budget_policy_trims_oldest_turns_when_exceeding_max_turns() {
    let pack = RecentConversationPack {
        entries: vec![
            history_entry(AiMessageRole::User, "turn1 user"),
            history_entry(AiMessageRole::Assistant, "turn1 assistant"),
            history_entry(AiMessageRole::User, "turn2 user"),
            history_entry(AiMessageRole::Assistant, "turn2 assistant"),
            history_entry(AiMessageRole::User, "turn3 user"),
            history_entry(AiMessageRole::Assistant, "turn3 assistant"),
        ],
    };

    let policy = ContextBudgetPolicy::new(2, 100_000);
    let trimmed = policy.trim(&pack);

    assert_eq!(trimmed.entries.len(), 4);
    assert_eq!(trimmed.entries[0].content, "turn2 user");
    assert_eq!(trimmed.entries[3].content, "turn3 assistant");
}

#[test]
fn context_budget_policy_trims_oldest_when_exceeding_max_bytes() {
    let pack = RecentConversationPack {
        entries: vec![
            history_entry(AiMessageRole::User, &"x".repeat(100)),
            history_entry(AiMessageRole::Assistant, &"y".repeat(100)),
            history_entry(AiMessageRole::User, &"z".repeat(50)),
        ],
    };

    let policy = ContextBudgetPolicy::new(100, 150);
    let trimmed = policy.trim(&pack);

    assert!(trimmed.entries.len() <= pack.entries.len());
    let total_bytes: usize = trimmed.entries.iter().map(|e| e.content.len()).sum();
    assert!(total_bytes <= 150);
}

#[test]
fn context_budget_policy_empty_pack_stays_empty() {
    let pack = RecentConversationPack::empty();
    let policy = ContextBudgetPolicy::new(10, 100_000);
    let trimmed = policy.trim(&pack);

    assert!(trimmed.entries.is_empty());
}

struct FakeSessionRepository {
    messages: Vec<AiMessage>,
    session_owner: Uuid,
}

impl FakeSessionRepository {
    fn new(messages: Vec<AiMessage>, session_owner: Uuid) -> Self {
        Self {
            messages,
            session_owner,
        }
    }
}

#[async_trait::async_trait]
impl AiSessionRepository for FakeSessionRepository {
    async fn upsert_session(
        &self,
        _session: &AiChatSession,
    ) -> maohuoban_ai_domain::ai::AiResult<()> {
        Ok(())
    }

    async fn update_session_header(
        &self,
        _session_id: Uuid,
        _actor_user_id: Uuid,
        _last_turn_id: Uuid,
        _last_message_at: chrono::DateTime<chrono::Utc>,
    ) -> maohuoban_ai_domain::ai::AiResult<()> {
        Ok(())
    }

    async fn insert_message(&self, _message: &AiMessage) -> maohuoban_ai_domain::ai::AiResult<()> {
        Ok(())
    }

    async fn list_sessions_by_actor(
        &self,
        _actor_user_id: Uuid,
        _limit: i64,
    ) -> maohuoban_ai_domain::ai::AiResult<Vec<AiChatSession>> {
        Ok(Vec::new())
    }

    async fn list_messages_by_session(
        &self,
        _session_id: Uuid,
    ) -> maohuoban_ai_domain::ai::AiResult<Vec<AiMessage>> {
        Ok(self.messages.clone())
    }

    async fn list_citations_by_session(
        &self,
        _session_id: Uuid,
    ) -> maohuoban_ai_domain::ai::AiResult<std::collections::HashMap<Uuid, Vec<AiCitation>>> {
        Ok(std::collections::HashMap::new())
    }

    async fn get_session(
        &self,
        _session_id: Uuid,
    ) -> maohuoban_ai_domain::ai::AiResult<Option<AiChatSession>> {
        // FakeSessionRepository 只为已知 session_id 返回会话
        // 用 static 比较避免与 session_id() 函数遮蔽
        let known = Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("session id");
        if _session_id != known {
            return Ok(None);
        }
        Ok(Some(AiChatSession {
            id: session_id(),
            actor_user_id: self.session_owner,
            primary_pet_id: None,
            surface: AiConversationSurface::HomePrivate,
            source_hint_id: None,
            source_task_id: None,
            chat_context_kind: None,
            abnormal_episode_id: None,
            agent_followup_id: None,
            title: "新对话".to_owned(),
            is_pinned: false,
            pet_display_snapshot: None,
            status: AiChatSessionStatus::Active,
            created_at: chrono::DateTime::from_timestamp(1, 0).expect("ts"),
            updated_at: chrono::DateTime::from_timestamp(1, 0).expect("ts"),
        }))
    }

    async fn find_active_abnormal_episode_session(
        &self,
        _actor_user_id: Uuid,
        _abnormal_episode_id: Uuid,
    ) -> maohuoban_ai_domain::ai::AiResult<Option<AiChatSession>> {
        Ok(None)
    }

    async fn rename_session(
        &self,
        _session_id: Uuid,
        _actor_user_id: Uuid,
        _title: &str,
    ) -> maohuoban_ai_domain::ai::AiResult<Option<AiChatSession>> {
        Ok(None)
    }

    async fn set_session_pinned(
        &self,
        _session_id: Uuid,
        _actor_user_id: Uuid,
        _is_pinned: bool,
    ) -> maohuoban_ai_domain::ai::AiResult<Option<AiChatSession>> {
        Ok(None)
    }

    async fn archive_session(
        &self,
        _session_id: Uuid,
        _actor_user_id: Uuid,
    ) -> maohuoban_ai_domain::ai::AiResult<Option<AiChatSession>> {
        Ok(None)
    }

    async fn insert_request_gate_log(
        &self,
        _log: &maohuoban_ai_application::ai::ports::AiRequestGateLog,
    ) -> maohuoban_ai_domain::ai::AiResult<()> {
        Ok(())
    }

    async fn insert_tool_access_log(
        &self,
        _log: &maohuoban_ai_application::ai::ports::AiToolAccessLog,
    ) -> maohuoban_ai_domain::ai::AiResult<()> {
        Ok(())
    }

    async fn insert_message_citations(
        &self,
        _message_id: Uuid,
        _session_id: Uuid,
        _citations: &[maohuoban_ai_domain::ai::AiCitation],
    ) -> maohuoban_ai_domain::ai::AiResult<()> {
        Ok(())
    }

    async fn insert_proposed_action(
        &self,
        _session_id: Uuid,
        _action: &maohuoban_ai_domain::ai::AiProposedAction,
    ) -> maohuoban_ai_domain::ai::AiResult<()> {
        Ok(())
    }

    async fn update_message_turn_id(
        &self,
        _message_id: Uuid,
        _turn_id: Uuid,
    ) -> maohuoban_ai_domain::ai::AiResult<()> {
        Ok(())
    }
}
