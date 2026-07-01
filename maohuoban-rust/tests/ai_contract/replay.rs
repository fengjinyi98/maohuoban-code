use maohuoban_ai_application::ai::ports::SessionEventRepository;
use maohuoban_ai_domain::ai::AgentSessionEventEntry;
use maohuoban_ai_infrastructure::repository::PostgresSessionEventRepository;
use serde::Deserialize;
use serde_json::json;

const REPLAY_CASE_JSON: &str = include_str!(
    "../../../docs/engineering/ai-agent-runtime/worktree-goals/eval-cases/replay_cases/provider_failure_turn.json"
);

// ReplayFixture WT10 固定回放样例
// 核心职责：
// - 固定 replay failure case 的事件序列
// - 固定按 turn 回放和终态期望
#[derive(Debug, Deserialize)]
struct ReplayFixture {
    schema_version: u32,
    name: String,
    case_type: String,
    description: String,
    session_surface: String,
    expected_terminal_state: String,
    event_sequence: Vec<String>,
    expected_replay_read: ExpectedReplayRead,
}

// ExpectedReplayRead replay 读取期望
// 核心职责：
// - 固定按 turn 读取
// - 固定事件顺序与 projector 终态事件
#[derive(Debug, Deserialize)]
struct ExpectedReplayRead {
    by_turn: bool,
    preserve_order: bool,
    projector_terminal_event: String,
}

#[tokio::test]
async fn ai_turn_replay_reads_event_sequence() {
    let fixture: ReplayFixture =
        serde_json::from_str(REPLAY_CASE_JSON).expect("parse replay fixture");
    assert_eq!(fixture.schema_version, 1);
    assert_eq!(fixture.name, "provider_failure_turn");
    assert_eq!(fixture.case_type, "failure");
    assert_eq!(fixture.session_surface, "home_private");
    assert_eq!(fixture.expected_terminal_state, "failed");
    assert!(!fixture.description.is_empty());

    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let repo = PostgresSessionEventRepository::new(app.pool().clone());

    let session_id = uuid::Uuid::new_v4();
    let turn_id = uuid::Uuid::new_v4();
    let other_turn_id = uuid::Uuid::new_v4();
    insert_chat_session(app.pool(), session_id).await;

    for event_name in &fixture.event_sequence {
        repo.append(&AgentSessionEventEntry::new(
            session_id,
            turn_id,
            event_name,
            json!({"turn_id": turn_id}),
        ))
        .await
        .expect("append replay event");
    }
    repo.append(&AgentSessionEventEntry::new(
        session_id,
        other_turn_id,
        "turn_started",
        json!({"turn_id": other_turn_id}),
    ))
    .await
    .expect("append other turn event");

    let replay = repo
        .replay_turn(turn_id)
        .await
        .expect("read replay event sequence");
    let sequence = replay.event_names();

    if fixture.expected_replay_read.by_turn {
        assert_eq!(replay.turn_id, turn_id);
        assert!(
            replay.events.iter().all(|event| event.turn_id == turn_id),
            "replay must only include events from requested turn: {replay:?}"
        );
    }
    if fixture.expected_replay_read.preserve_order {
        assert_eq!(sequence, fixture.event_sequence);
    }
    assert_eq!(
        replay_projector_terminal_event(&sequence),
        fixture.expected_replay_read.projector_terminal_event
    );
}

fn replay_projector_terminal_event(sequence: &[&str]) -> &'static str {
    match sequence.last().copied() {
        Some("turn_failed" | "provider_error") => "error",
        Some("turn_finished") => "answer_completed",
        terminal => panic!("unsupported replay terminal event {terminal:?}"),
    }
}

async fn insert_chat_session(pool: &sqlx::PgPool, session_id: uuid::Uuid) {
    sqlx::query(
        r"
        INSERT INTO ai_chat_sessions
            (id, actor_user_id, surface, title, status, created_at, updated_at)
        VALUES ($1, $2, 'home_private', 'replay fixture', 'active', now(), now())
        ",
    )
    .bind(session_id)
    .bind(uuid::Uuid::new_v4())
    .execute(pool)
    .await
    .expect("insert chat session fixture");
}
