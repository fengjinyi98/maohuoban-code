use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AiChatSession, AiMessage, AiResult};
use uuid::Uuid;

/// AiSessionRepository AI 会话仓储端口
/// 核心职责：
/// - 持久化和查询 AI 会话、消息
/// - application 只依赖该 trait，不感知具体数据库实现
#[async_trait]
pub trait AiSessionRepository: Send + Sync {
    /// upsert_session 创建或更新会话
    async fn upsert_session(&self, session: &AiChatSession) -> AiResult<()>;

    /// insert_message 插入一条消息
    async fn insert_message(&self, message: &AiMessage) -> AiResult<()>;

    /// list_sessions_by_actor 返回当前用户会话列表（按更新时间降序）
    async fn list_sessions_by_actor(
        &self,
        actor_user_id: Uuid,
        limit: i64,
    ) -> AiResult<Vec<AiChatSession>>;

    /// list_messages_by_session 返回指定会话的消息列表（按时间升序）
    async fn list_messages_by_session(&self, session_id: Uuid) -> AiResult<Vec<AiMessage>>;

    /// get_session 获取单个会话（含归属校验）
    async fn get_session(&self, session_id: Uuid) -> AiResult<Option<AiChatSession>>;
}
