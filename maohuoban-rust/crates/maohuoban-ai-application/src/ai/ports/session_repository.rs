use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AiChatSession, AiMessage, AiResult};
use uuid::Uuid;

/// AiRequestGateLog AI 请求 gate 审计日志
/// 核心职责：
/// - 记录意图闸门决策和上下文加载状态
/// - 避免审计表保存完整用户原文
pub struct AiRequestGateLog {
    pub session_id: Option<Uuid>,
    pub actor_user_id: Uuid,
    pub intent: String,
    pub gate_decision: String,
    pub context_loaded: bool,
    pub request_hash: String,
    pub resolved_pet_id: Option<Uuid>,
    pub selected_pet_id: Option<Uuid>,
    pub risk_signal: Option<String>,
    pub estimated_input_tokens: i32,
}

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

    /// insert_request_gate_log 写入请求 gate 审计日志
    async fn insert_request_gate_log(&self, log: &AiRequestGateLog) -> AiResult<()>;
}
