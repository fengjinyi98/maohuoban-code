use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AiChatSession, AiCitation, AiMessage, AiProposedAction, AiResult};
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

/// AiToolAccessLog AI 工具访问审计日志
/// 核心职责：
/// - 记录 Agent Gateway 工具调用和授权结果
/// - 只保存引用 ID 和风险标签，避免写入完整私有 payload
pub struct AiToolAccessLog {
    pub session_id: Option<Uuid>,
    pub actor_user_id: Uuid,
    pub tool_name: String,
    pub requested_scope: String,
    pub target_pet_id: Option<Uuid>,
    pub allowed: bool,
    pub denied_reason: Option<String>,
    pub returned_ref_ids: Vec<String>,
    pub duration_ms: i64,
    pub risk_signal: Option<String>,
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

    /// list_sessions_by_actor 返回当前用户会话列表（置顶优先，按更新时间降序）
    async fn list_sessions_by_actor(
        &self,
        actor_user_id: Uuid,
        limit: i64,
    ) -> AiResult<Vec<AiChatSession>>;

    /// list_messages_by_session 返回指定会话的消息列表（按时间升序）
    async fn list_messages_by_session(&self, session_id: Uuid) -> AiResult<Vec<AiMessage>>;

    /// get_session 获取单个会话（含归属校验）
    async fn get_session(&self, session_id: Uuid) -> AiResult<Option<AiChatSession>>;

    /// rename_session 重命名当前用户会话
    async fn rename_session(
        &self,
        session_id: Uuid,
        actor_user_id: Uuid,
        title: &str,
    ) -> AiResult<Option<AiChatSession>>;

    /// set_session_pinned 更新当前用户会话置顶状态
    async fn set_session_pinned(
        &self,
        session_id: Uuid,
        actor_user_id: Uuid,
        is_pinned: bool,
    ) -> AiResult<Option<AiChatSession>>;

    /// archive_session 归档当前用户会话
    async fn archive_session(
        &self,
        session_id: Uuid,
        actor_user_id: Uuid,
    ) -> AiResult<Option<AiChatSession>>;

    /// insert_request_gate_log 写入请求 gate 审计日志
    async fn insert_request_gate_log(&self, log: &AiRequestGateLog) -> AiResult<()>;

    /// insert_tool_access_log 写入工具访问审计日志
    async fn insert_tool_access_log(&self, log: &AiToolAccessLog) -> AiResult<()>;

    /// insert_message_citations 写入助手消息引用
    async fn insert_message_citations(
        &self,
        message_id: Uuid,
        session_id: Uuid,
        citations: &[AiCitation],
    ) -> AiResult<()>;

    /// insert_proposed_action 写入待确认建议动作
    async fn insert_proposed_action(
        &self,
        session_id: Uuid,
        action: &AiProposedAction,
    ) -> AiResult<()>;

    /// update_message_turn_id 更新消息的 turn_id 关联
    /// 核心职责：
    /// - 在 turn 行插入后回写消息的 turn_id
    /// - 解决 ai_messages.turn_id ↔ ai_session_turns.user_message_id 循环外键
    async fn update_message_turn_id(&self, message_id: Uuid, turn_id: Uuid) -> AiResult<()>;
}
