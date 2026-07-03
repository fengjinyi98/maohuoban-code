/// `insert_chat_session_fixture` 写入 AI 会话测试夹具
/// 核心职责：
/// - 为 session event 仓储测试提供已存在的会话行
/// - 固定最小字段集合，避免测试依赖 HTTP 入口
pub async fn insert_chat_session_fixture(pool: &sqlx::PgPool, session_id: uuid::Uuid) {
    sqlx::query(
        r"
        INSERT INTO ai_chat_sessions
            (id, actor_user_id, surface, title, status, created_at, updated_at)
        VALUES ($1, $2, 'home_private', 'session event fixture', 'active', now(), now())
        ",
    )
    .bind(session_id)
    .bind(uuid::Uuid::new_v4())
    .execute(pool)
    .await
    .expect("insert chat session fixture");
}

/// `insert_ai_message_fixture` 写入 AI 消息测试夹具
/// 核心职责：
/// - 为 session event 仓储测试提供可关联的 assistant message
/// - 固定最小字段集合，避免测试依赖完整对话流
pub async fn insert_ai_message_fixture(
    pool: &sqlx::PgPool,
    session_id: uuid::Uuid,
    message_id: uuid::Uuid,
) {
    sqlx::query(
        r"
        INSERT INTO ai_messages
            (id, session_id, role, content, status, citations, created_at)
        VALUES ($1, $2, 'assistant', '照护建议', 'completed', '[]'::jsonb, now())
        ",
    )
    .bind(message_id)
    .bind(session_id)
    .execute(pool)
    .await
    .expect("insert ai message fixture");
}
