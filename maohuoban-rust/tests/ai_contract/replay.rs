use maohuoban_ai_application::ai::ports::SessionEventRepository;
use maohuoban_ai_domain::ai::AgentSessionEventEntry;
use maohuoban_ai_infrastructure::repository::PostgresSessionEventRepository;
use serde_json::json;

#[tokio::test]
async fn ai_turn_replay_reads_event_sequence() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let repo = PostgresSessionEventRepository::new(app.pool().clone());

    let session_id = uuid::Uuid::new_v4();
    let turn_id = uuid::Uuid::new_v4();
    insert_chat_session(app.pool(), session_id).await;

    for event_name in [
        "turn_started",
        "model_call_started",
        "provider_error",
        "turn_failed",
    ] {
        repo.append(&AgentSessionEventEntry::new(
            session_id,
            turn_id,
            event_name,
            json!({"turn_id": turn_id}),
        ))
        .await
        .expect("append replay event");
    }

    let replay = repo
        .replay_turn(turn_id)
        .await
        .expect("read replay event sequence");
    let sequence = replay.event_names();

    assert_eq!(
        sequence,
        vec![
            "turn_started",
            "model_call_started",
            "provider_error",
            "turn_failed"
        ]
    );
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
