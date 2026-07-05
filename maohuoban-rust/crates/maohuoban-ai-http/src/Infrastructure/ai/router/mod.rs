//! router AI HTTP 路由
//! 核心职责：
//! - 承载 /api/v1/ai/chat、/api/v1/ai/chat/stream、历史接口的 HTTP DTO 和路由
//! - 用户身份只来自后端 token，不信任请求体 actor_user_id 字段

mod chat;
mod diagnostics;
mod diagnostics_common;
mod history;
mod history_diagnostics;

use std::sync::Arc;

use axum::{
    Router,
    routing::{delete, get, patch, post},
};
use maohuoban_ai_application::ai::pet_resolver::AiPetResolver;
use maohuoban_ai_application::ai::ports::{
    AbnormalFollowupPlanProvider, AiSessionRepository, ChatTurnTransactionPort,
    FoodInventoryHintProvider, LlmProvider, MemoryRepository, PetAbnormalEpisodeFactProvider,
    PetDietConfirmationCandidateProvider, PetDietFactProvider, PetHealthQuickFactProvider,
    PetIdentityFactProvider, PetObservationWriteProvider, SessionSummaryRepository,
    SessionTurnRepository,
};
use maohuoban_ai_application::ai::runtime::AgentRuntimeEngineMode;

pub use self::chat::{require_ai_chat_auth, snapshot_ai_chat_request};
/// AiHttpState AI HTTP 状态
/// 核心职责：
/// - 持有 LLM Provider、会话仓储和认证服务
/// - 作为 axum handler 的共享状态
#[derive(Clone)]
pub struct AiHttpState {
    pub llm_provider: Arc<dyn LlmProvider>,
    pub runtime_engine_mode: AgentRuntimeEngineMode,
    pub session_repository: Arc<dyn AiSessionRepository>,
    pub session_turn_repository: Arc<dyn SessionTurnRepository>,
    pub chat_turn_transaction: Arc<dyn ChatTurnTransactionPort>,
    pub session_summary_repository: Arc<dyn SessionSummaryRepository>,
    pub memory_repository: Arc<dyn MemoryRepository>,
    pub pet_resolver: Arc<AiPetResolver>,
    pub pet_context_providers: AiPetContextProviders,
    pub observation_write_provider: Arc<dyn PetObservationWriteProvider>,
}

/// AiPetContextProviders AI 宠物上下文 provider 集合
/// 核心职责：
/// - 聚合身份、当前饮食、储物柜线索和待确认候选 provider
/// - 控制 AiHttpState 构造参数数量，保持上下文依赖边界清晰
#[derive(Clone)]
pub struct AiPetContextProviders {
    pub identity_fact_provider: Arc<dyn PetIdentityFactProvider>,
    pub abnormal_episode_fact_provider: Arc<dyn PetAbnormalEpisodeFactProvider>,
    pub diet_fact_provider: Arc<dyn PetDietFactProvider>,
    pub health_quick_fact_provider: Arc<dyn PetHealthQuickFactProvider>,
    pub food_inventory_hint_provider: Arc<dyn FoodInventoryHintProvider>,
    pub diet_confirmation_candidate_provider: Arc<dyn PetDietConfirmationCandidateProvider>,
    pub observation_write_provider: Arc<dyn PetObservationWriteProvider>,
    pub abnormal_followup_plan_provider: Arc<dyn AbnormalFollowupPlanProvider>,
}

/// AiPetContextProviderParts AI 宠物上下文 provider 构造参数
/// 核心职责：
/// - 以具名字段收敛 provider 集合依赖
/// - 避免构造函数参数随工具增长继续膨胀
pub struct AiPetContextProviderParts {
    pub identity_fact_provider: Arc<dyn PetIdentityFactProvider>,
    pub abnormal_episode_fact_provider: Arc<dyn PetAbnormalEpisodeFactProvider>,
    pub diet_fact_provider: Arc<dyn PetDietFactProvider>,
    pub health_quick_fact_provider: Arc<dyn PetHealthQuickFactProvider>,
    pub food_inventory_hint_provider: Arc<dyn FoodInventoryHintProvider>,
    pub diet_confirmation_candidate_provider: Arc<dyn PetDietConfirmationCandidateProvider>,
    pub observation_write_provider: Arc<dyn PetObservationWriteProvider>,
    pub abnormal_followup_plan_provider: Arc<dyn AbnormalFollowupPlanProvider>,
}

impl AiPetContextProviders {
    /// new 构造宠物上下文 provider 集合
    #[must_use]
    pub fn new(parts: AiPetContextProviderParts) -> Self {
        Self {
            identity_fact_provider: parts.identity_fact_provider,
            abnormal_episode_fact_provider: parts.abnormal_episode_fact_provider,
            diet_fact_provider: parts.diet_fact_provider,
            health_quick_fact_provider: parts.health_quick_fact_provider,
            food_inventory_hint_provider: parts.food_inventory_hint_provider,
            diet_confirmation_candidate_provider: parts.diet_confirmation_candidate_provider,
            observation_write_provider: parts.observation_write_provider,
            abnormal_followup_plan_provider: parts.abnormal_followup_plan_provider,
        }
    }
}

/// build_ai_chat_router 构建 AI chat 路由
/// 核心职责：
/// - 仅注册 chat 与 chat/stream 业务 handler
/// - 将请求快照与认证策略留给根路由树统一装配
pub fn build_ai_chat_router() -> Router<AiHttpState> {
    Router::new()
        .route("/api/v1/ai/chat", post(chat::handle_chat))
        .route("/api/v1/ai/chat/stream", post(chat::handle_chat_stream))
}

/// build_ai_history_router 构建 AI 历史路由
/// 核心职责：
/// - 仅注册 AI 会话历史读取与修改 handler
/// - 将用户认证策略留给根路由树统一装配
pub fn build_ai_history_router() -> Router<AiHttpState> {
    Router::new()
        .route(
            "/api/v1/ai/chat-sessions",
            get(history::handle_list_sessions),
        )
        .route(
            "/api/v1/ai/chat-sessions/{id}/title",
            patch(history::handle_rename_session),
        )
        .route(
            "/api/v1/ai/chat-sessions/{id}/pin",
            patch(history::handle_pin_session),
        )
        .route(
            "/api/v1/ai/chat-sessions/{id}",
            delete(history::handle_delete_session),
        )
        .route(
            "/api/v1/ai/chat-sessions/{id}/messages",
            get(history::handle_get_session_messages),
        )
}

/// build_ai_router_state 绑定 AI 路由共享状态
/// 核心职责：
/// - 为已装配完成的 AI 子路由挂载统一状态
/// - 避免根路由树重复感知 AI HTTP 状态细节
pub fn build_ai_router_state(router: Router<AiHttpState>, state: AiHttpState) -> Router {
    router.with_state(state)
}
