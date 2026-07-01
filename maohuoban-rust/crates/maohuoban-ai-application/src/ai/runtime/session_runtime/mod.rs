use maohuoban_ai_domain::ai::{AgentId, AgentSessionState, AiConversationSurface};
use uuid::Uuid;

use super::{AgentSession, LoopEngine};

/// AgentSessionRuntime Runtime 外层入口
/// 核心职责：
/// - 创建当前 in-memory AgentSession
/// - 预留 switch / resume / fork 契约占位，后续 worktree 接入持久化
#[derive(Debug, Clone, Copy, Default)]
pub struct AgentSessionRuntime<E> {
    _engine: std::marker::PhantomData<E>,
}

impl<E> AgentSessionRuntime<E> {
    /// initial_state 创建最小 session state
    #[must_use]
    pub fn initial_state(
        chat_session_id: Uuid,
        agent_id: AgentId,
        surface: AiConversationSurface,
    ) -> AgentSessionState {
        AgentSessionState::new(chat_session_id, agent_id, surface)
    }
}

impl<E: LoopEngine> AgentSessionRuntime<E> {
    /// create_session 创建当前 in-memory session
    #[must_use]
    pub fn create_session(
        chat_session_id: Uuid,
        agent_id: AgentId,
        surface: AiConversationSurface,
        engine: E,
    ) -> AgentSession<E> {
        AgentSession::new(chat_session_id, agent_id, surface, engine)
    }

    /// switch_session 预留 session 切换契约
    #[must_use]
    pub fn switch_session(_chat_session_id: Uuid) -> Option<AgentSessionState> {
        None
    }

    /// resume_session 预留 session 恢复契约
    #[must_use]
    pub fn resume_session(_chat_session_id: Uuid) -> Option<AgentSessionState> {
        None
    }

    /// fork_session 预留 session fork 契约
    #[must_use]
    pub fn fork_session(_chat_session_id: Uuid) -> Option<AgentSessionState> {
        None
    }
}
