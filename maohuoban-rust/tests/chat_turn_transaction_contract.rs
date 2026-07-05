// chat_turn_transaction_contract Ingress 事务合同测试
// 核心职责：
// - 验证 ingress 事务会原子写入 session、user message、turn 和 gate log
// - 防止参数占位符错误导致整笔 AI 会话入口持久化静默失败

use chrono::Utc;
use maohuoban_ai_application::ai::ports::{
    AiRequestGateLog, ChatTurnTransactionPort, IngressTxInput,
};
use maohuoban_ai_domain::ai::{
    AgentTurnId, AiChatSession, AiChatSessionStatus, AiConversationSurface, AiMessage,
    AiMessageRole, AiMessageStatus, AiSessionTurn, AiSessionTurnStatus,
};
use maohuoban_ai_infrastructure::repository::PostgresChatTurnTransaction;
use uuid::Uuid;

struct IngressFixture {
    session: AiChatSession,
    user_message: AiMessage,
    turn: AiSessionTurn,
    gate_log: AiRequestGateLog,
}

#[tokio::test]
async fn ingress_transaction_persists_session_message_turn_and_gate_log() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let fixture = build_ingress_fixture();

    let transaction = PostgresChatTurnTransaction::new(app.pool().clone());
    transaction
        .persist_ingress_tx(&IngressTxInput {
            session: &fixture.session,
            user_message: &fixture.user_message,
            turn: &fixture.turn,
            gate_log: &fixture.gate_log,
        })
        .await
        .expect("persist ingress tx");

    assert_ingress_fixture_persisted(&app, &fixture).await;
}

#[tokio::test]
async fn ingress_transaction_keeps_existing_session_title_on_later_turns() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let first_fixture = build_ingress_fixture();
    let mut second_fixture = build_ingress_fixture();
    second_fixture.session.id = first_fixture.session.id;
    second_fixture.session.actor_user_id = first_fixture.session.actor_user_id;
    second_fixture.session.title = "第二轮不应覆盖标题".to_owned();
    second_fixture.user_message.session_id = first_fixture.session.id;
    second_fixture.turn.session_id = first_fixture.session.id;
    second_fixture.turn.actor_user_id = first_fixture.session.actor_user_id;
    second_fixture.gate_log.session_id = Some(first_fixture.session.id);
    second_fixture.gate_log.actor_user_id = first_fixture.session.actor_user_id;

    let transaction = PostgresChatTurnTransaction::new(app.pool().clone());
    transaction
        .persist_ingress_tx(&IngressTxInput {
            session: &first_fixture.session,
            user_message: &first_fixture.user_message,
            turn: &first_fixture.turn,
            gate_log: &first_fixture.gate_log,
        })
        .await
        .expect("persist first ingress tx");
    transaction
        .persist_ingress_tx(&IngressTxInput {
            session: &second_fixture.session,
            user_message: &second_fixture.user_message,
            turn: &second_fixture.turn,
            gate_log: &second_fixture.gate_log,
        })
        .await
        .expect("persist second ingress tx");

    let title: String = sqlx::query_scalar("SELECT title FROM ai_chat_sessions WHERE id = $1")
        .bind(first_fixture.session.id)
        .fetch_one(app.pool())
        .await
        .expect("read session title");

    assert_eq!(title, first_fixture.session.title);
}

fn build_ingress_fixture() -> IngressFixture {
    let now = Utc::now();
    let actor_user_id = Uuid::new_v4();
    let session_id = Uuid::new_v4();
    let user_message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();

    IngressFixture {
        session: AiChatSession {
            id: session_id,
            actor_user_id,
            primary_pet_id: None,
            surface: AiConversationSurface::HomePrivate,
            source_hint_id: None,
            source_task_id: None,
            chat_context_kind: None,
            abnormal_episode_id: None,
            agent_followup_id: None,
            title: "测试事务入口".to_owned(),
            is_pinned: false,
            pet_display_snapshot: None,
            status: AiChatSessionStatus::Active,
            created_at: now,
            updated_at: now,
        },
        user_message: AiMessage {
            id: user_message_id,
            session_id,
            turn_id: None,
            role: AiMessageRole::User,
            content: "毛球今天怎么样".to_owned(),
            status: AiMessageStatus::Completed,
            citations: Vec::new(),
            content_blocks: Vec::new(),
            model: None,
            provider: None,
            finish_reason: None,
            usage_input_tokens: None,
            usage_output_tokens: None,
            verification: None,
            created_at: now,
        },
        turn: AiSessionTurn {
            id: turn_id.as_uuid(),
            session_id,
            actor_user_id,
            user_message_id,
            assistant_message_id: None,
            intent: "pet_care".to_owned(),
            gate_decision: "load_context".to_owned(),
            resolved_pet_id: None,
            engine_mode: "self_hosted".to_owned(),
            surface: AiConversationSurface::HomePrivate,
            status: AiSessionTurnStatus::Running,
            finish_reason: None,
            error_code: None,
            retryable: None,
            started_at: now,
            finished_at: None,
        },
        gate_log: AiRequestGateLog {
            session_id: Some(session_id),
            actor_user_id,
            intent: "pet_care".to_owned(),
            gate_decision: "load_context".to_owned(),
            context_loaded: true,
            request_hash: "test-hash".to_owned(),
            resolved_pet_id: None,
            selected_pet_id: None,
            risk_signal: None,
            estimated_input_tokens: 8,
        },
    }
}

async fn assert_ingress_fixture_persisted(
    app: &maohuoban_rust::test_support::AuthTestApp,
    fixture: &IngressFixture,
) {
    let session_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM ai_chat_sessions WHERE id = $1")
            .bind(fixture.session.id)
            .fetch_one(app.pool())
            .await
            .expect("count session");
    let message_turn_id: Option<Uuid> =
        sqlx::query_scalar("SELECT turn_id FROM ai_messages WHERE id = $1")
            .bind(fixture.user_message.id)
            .fetch_one(app.pool())
            .await
            .expect("read message turn id");
    let turn_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM ai_session_turns WHERE id = $1")
        .bind(fixture.turn.id)
        .fetch_one(app.pool())
        .await
        .expect("count turn");
    let gate_log_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM ai_request_gate_logs WHERE session_id = $1")
            .bind(fixture.session.id)
            .fetch_one(app.pool())
            .await
            .expect("count gate log");

    assert_eq!(session_count, 1);
    assert_eq!(message_turn_id, Some(fixture.turn.id));
    assert_eq!(turn_count, 1);
    assert_eq!(gate_log_count, 1);
}
