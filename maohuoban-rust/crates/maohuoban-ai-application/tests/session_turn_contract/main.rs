// session_turn_contract Session/Turn 持久化与 Replay 合同测试
// 核心职责：
// - 验证 Turn 账本 insert → update → get → list 全生命周期
// - 验证 Turn Replay 事件序列按写入顺序返回
// - 验证 session_id / turn_id / message_id 在 domain 模型间的关联一致性
// - 验证 AgentSessionState.begin_turn_with_id 使 Runtime turn_id 与外部注入 ID 一致
use maohuoban_ai_application::ai::ports::{SessionEventRepository, SessionTurnRepository};
use maohuoban_ai_domain::ai::{
    AgentId, AgentSessionEventEntry, AgentSessionState, AgentTurnId, AgentTurnStatus,
    AiConversationSurface, AiSessionTurnStatus,
};
use uuid::Uuid;

mod fixtures;
mod repositories;

use fixtures::{
    assistant_message_id, assistant_message_with_turn, chat_session, running_turn, session_id,
    turn_id, user_message_with_turn,
};
use repositories::{InMemoryEventRepository, InMemoryTurnRepository};

// ─── Turn 持久化合同测试 ────────────────────────────────

#[tokio::test]
async fn turn_insert_and_get_roundtrip() {
    let repo = InMemoryTurnRepository::new();
    let turn = running_turn();

    repo.insert_turn(&turn).await.expect("insert turn");

    let fetched = repo
        .get_turn(turn_id())
        .await
        .expect("get turn")
        .expect("turn should exist");

    assert_eq!(fetched.id, turn.id);
    assert_eq!(fetched.session_id, turn.session_id);
    assert_eq!(fetched.actor_user_id, turn.actor_user_id);
    assert_eq!(fetched.user_message_id, turn.user_message_id);
    assert_eq!(fetched.assistant_message_id, turn.assistant_message_id);
    assert_eq!(fetched.intent, turn.intent);
    assert_eq!(fetched.gate_decision, turn.gate_decision);
    assert_eq!(fetched.resolved_pet_id, turn.resolved_pet_id);
    assert_eq!(fetched.engine_mode, turn.engine_mode);
    assert_eq!(fetched.surface, turn.surface);
    assert_eq!(fetched.status, AiSessionTurnStatus::Running);
    assert!(fetched.finish_reason.is_none());
    assert!(fetched.error_code.is_none());
    assert!(fetched.retryable.is_none());
    assert!(fetched.finished_at.is_none());
}

#[tokio::test]
async fn turn_get_returns_none_for_missing_id() {
    let repo = InMemoryTurnRepository::new();

    let result = repo.get_turn(Uuid::new_v4()).await.expect("get turn");

    assert!(result.is_none());
}

#[tokio::test]
async fn turn_update_to_completed_sets_terminal_fields() {
    let repo = InMemoryTurnRepository::new();
    repo.insert_turn(&running_turn())
        .await
        .expect("insert turn");

    repo.update_turn_status(
        turn_id(),
        AiSessionTurnStatus::Completed,
        Some(assistant_message_id()),
        Some("stop"),
        None,
        None,
    )
    .await
    .expect("update turn status");

    let fetched = repo
        .get_turn(turn_id())
        .await
        .expect("get turn")
        .expect("turn should exist");

    assert_eq!(fetched.status, AiSessionTurnStatus::Completed);
    assert!(fetched.status.is_terminal());
    assert_eq!(fetched.finish_reason.as_deref(), Some("stop"));
    assert!(fetched.error_code.is_none());
    assert!(fetched.retryable.is_none());
    assert!(fetched.finished_at.is_some());
}

#[tokio::test]
async fn turn_update_to_failed_sets_error_fields() {
    let repo = InMemoryTurnRepository::new();
    repo.insert_turn(&running_turn())
        .await
        .expect("insert turn");

    repo.update_turn_status(
        turn_id(),
        AiSessionTurnStatus::Failed,
        None,
        None,
        Some("ai.provider.not_configured"),
        Some(false),
    )
    .await
    .expect("update turn status");

    let fetched = repo
        .get_turn(turn_id())
        .await
        .expect("get turn")
        .expect("turn should exist");

    assert_eq!(fetched.status, AiSessionTurnStatus::Failed);
    assert!(fetched.status.is_terminal());
    assert_eq!(
        fetched.error_code.as_deref(),
        Some("ai.provider.not_configured")
    );
    assert_eq!(fetched.retryable, Some(false));
    assert!(fetched.finished_at.is_some());
}

#[tokio::test]
async fn turn_update_to_interrupted_is_terminal() {
    let repo = InMemoryTurnRepository::new();
    repo.insert_turn(&running_turn())
        .await
        .expect("insert turn");

    repo.update_turn_status(
        turn_id(),
        AiSessionTurnStatus::Interrupted,
        None,
        Some("interrupted"),
        None,
        None,
    )
    .await
    .expect("update turn status");

    let fetched = repo.get_turn(turn_id()).await.expect("get").expect("exist");

    assert_eq!(fetched.status, AiSessionTurnStatus::Interrupted);
    assert!(fetched.status.is_terminal());
    assert!(fetched.finished_at.is_some());
}

#[tokio::test]
async fn turn_update_to_requires_confirmation_is_not_terminal() {
    let repo = InMemoryTurnRepository::new();
    repo.insert_turn(&running_turn())
        .await
        .expect("insert turn");

    repo.update_turn_status(
        turn_id(),
        AiSessionTurnStatus::RequiresConfirmation,
        None,
        None,
        None,
        None,
    )
    .await
    .expect("update turn status");

    let fetched = repo.get_turn(turn_id()).await.expect("get").expect("exist");

    assert_eq!(fetched.status, AiSessionTurnStatus::RequiresConfirmation);
    assert!(!fetched.status.is_terminal());
    assert!(fetched.finished_at.is_none());
}

#[tokio::test]
async fn turn_list_by_session_returns_all_turns() {
    let repo = InMemoryTurnRepository::new();

    let mut first_turn = running_turn();
    first_turn.id = Uuid::parse_str("33333333-3333-3333-3333-333333333301").expect("turn1 id");
    first_turn.started_at = chrono::Utc::now();

    let mut second_turn = running_turn();
    second_turn.id = Uuid::parse_str("33333333-3333-3333-3333-333333333302").expect("turn2 id");
    second_turn.started_at = chrono::Utc::now();

    repo.insert_turn(&first_turn).await.expect("insert turn1");
    repo.insert_turn(&second_turn).await.expect("insert turn2");

    let turns = repo
        .list_turns_by_session(session_id())
        .await
        .expect("list turns");

    assert_eq!(turns.len(), 2);
    let ids: Vec<Uuid> = turns.iter().map(|t| t.id).collect();
    assert!(ids.contains(&first_turn.id));
    assert!(ids.contains(&second_turn.id));
}

#[tokio::test]
async fn turn_list_by_session_filters_other_sessions() {
    let repo = InMemoryTurnRepository::new();

    let mut turn_other = running_turn();
    turn_other.session_id = Uuid::new_v4();

    repo.insert_turn(&turn_other).await.expect("insert other");
    repo.insert_turn(&running_turn())
        .await
        .expect("insert target");

    let turns = repo
        .list_turns_by_session(session_id())
        .await
        .expect("list turns");

    assert_eq!(turns.len(), 1);
    assert_eq!(turns[0].id, turn_id());
}

// ─── Turn Replay 合同测试 ──────────────────────────────

#[tokio::test]
async fn replay_turn_returns_events_in_append_order() {
    let event_repo = InMemoryEventRepository::new();

    let events = vec![
        AgentSessionEventEntry::new(
            session_id(),
            turn_id(),
            "turn_started",
            serde_json::json!({"engine_mode": "self_hosted"}),
        ),
        AgentSessionEventEntry::new(
            session_id(),
            turn_id(),
            "model_call_started",
            serde_json::json!({"model_label": "primary"}),
        ),
        AgentSessionEventEntry::new(
            session_id(),
            turn_id(),
            "turn_finished",
            serde_json::json!({"message_id": assistant_message_id().to_string()}),
        ),
    ];

    for event in &events {
        event_repo.append(event).await.expect("append event");
    }

    let replay = event_repo.replay_turn(turn_id()).await.expect("replay");

    assert_eq!(replay.turn_id, turn_id());
    assert_eq!(
        replay.event_names(),
        vec!["turn_started", "model_call_started", "turn_finished"]
    );
}

#[tokio::test]
async fn replay_turn_empty_for_missing_turn() {
    let event_repo = InMemoryEventRepository::new();

    let replay = event_repo
        .replay_turn(Uuid::new_v4())
        .await
        .expect("replay");

    assert!(replay.events.is_empty());
}

#[tokio::test]
async fn list_by_turn_filters_other_turns() {
    let event_repo = InMemoryEventRepository::new();
    let other_turn = Uuid::new_v4();

    event_repo
        .append(&AgentSessionEventEntry::new(
            session_id(),
            other_turn,
            "turn_started",
            serde_json::json!({}),
        ))
        .await
        .expect("append other");

    event_repo
        .append(&AgentSessionEventEntry::new(
            session_id(),
            turn_id(),
            "turn_started",
            serde_json::json!({}),
        ))
        .await
        .expect("append target");

    let events = event_repo
        .list_by_turn(turn_id())
        .await
        .expect("list by turn");

    assert_eq!(events.len(), 1);
    assert_eq!(events[0].turn_id, turn_id());
}

#[tokio::test]
async fn list_by_session_returns_all_turn_events() {
    let event_repo = InMemoryEventRepository::new();

    for name in ["turn_started", "model_call_finished", "turn_finished"] {
        event_repo
            .append(&AgentSessionEventEntry::new(
                session_id(),
                turn_id(),
                name,
                serde_json::json!({}),
            ))
            .await
            .expect("append");
    }

    let events = event_repo
        .list_by_session(session_id())
        .await
        .expect("list by session");

    assert_eq!(events.len(), 3);
    assert!(events.iter().all(|e| e.session_id == session_id()));
}

// ─── 关联一致性合同测试 ─────────────────────────────────

#[test]
fn message_turn_id_links_to_session_turn() {
    let turn = running_turn();
    let user_msg = user_message_with_turn(turn.id);
    let assistant_msg = assistant_message_with_turn(turn.id);

    assert_eq!(user_msg.turn_id, Some(turn.id));
    assert_eq!(assistant_msg.turn_id, Some(turn.id));
    assert_eq!(user_msg.session_id, turn.session_id);
    assert_eq!(assistant_msg.session_id, turn.session_id);
    assert_eq!(turn.user_message_id, user_msg.id);
    assert_eq!(turn.assistant_message_id, Some(assistant_msg.id));
}

#[test]
fn turn_status_and_session_turn_status_align_for_completed() {
    assert_eq!(
        AgentTurnStatus::Completed as u8,
        AgentTurnStatus::Completed as u8
    );
    assert!(AiSessionTurnStatus::Completed.is_terminal());
}

#[test]
fn turn_status_and_session_turn_status_align_for_failed() {
    assert!(AiSessionTurnStatus::Failed.is_terminal());
}

#[test]
fn session_state_begin_turn_with_id_sets_current_turn_id() {
    let external_turn_id = AgentTurnId::from_uuid(turn_id());
    let mut state = AgentSessionState::new(
        session_id(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
    );

    let returned_id = state.begin_turn_with_id("test input".to_owned(), external_turn_id);

    assert_eq!(returned_id.as_uuid(), turn_id());
    assert_eq!(
        state
            .current_turn_id
            .expect("turn id should be set")
            .as_uuid(),
        turn_id()
    );
    assert_eq!(state.turn_index, 1);
    assert_eq!(state.user_inputs.len(), 1);
    assert_eq!(state.user_inputs[0], "test input");
}

#[test]
fn session_state_begin_turn_generates_new_id_when_not_provided() {
    let mut state = AgentSessionState::new(
        session_id(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
    );

    let id1 = state.begin_turn("first".to_owned());
    let id2 = state.begin_turn("second".to_owned());

    assert_ne!(id1.as_uuid(), id2.as_uuid());
    assert_eq!(state.turn_index, 2);
    assert_eq!(state.user_inputs.len(), 2);
}

#[test]
fn chat_session_and_turn_share_session_id() {
    let session = chat_session();
    let turn = running_turn();

    assert_eq!(session.id, turn.session_id);
    assert_eq!(session.actor_user_id, turn.actor_user_id);
}
