//! router AI HTTP 路由
//! 核心职责：
//! - 承载 /api/v1/ai/chat、/api/v1/ai/chat/stream、历史接口的 HTTP DTO 和路由
//! - 用户身份只来自后端 token，不信任请求体 actor_user_id 字段

mod auth;
mod chat;
mod diagnostics;
mod diagnostics_common;
mod history;
mod history_diagnostics;

use std::sync::Arc;

use axum::{
    Router,
    extract::FromRef,
    routing::{delete, get, patch, post},
};
use maohuoban_ai_application::ai::pet_resolver::AiPetResolver;
use maohuoban_ai_application::ai::ports::{
    AiSessionRepository, ChatTurnTransactionPort, FoodInventoryHintProvider, LlmProvider,
    MemoryRepository, PetDietConfirmationCandidateProvider, PetDietFactProvider,
    PetIdentityFactProvider, SessionSummaryRepository, SessionTurnRepository,
};
use maohuoban_ai_application::ai::runtime::AgentRuntimeEngineMode;
use maohuoban_ai_application::ai::stream::AiStreamPipeline;
use maohuoban_auth_application::auth::AuthService;

/// AiHttpState AI HTTP 状态
/// 核心职责：
/// - 持有 AI stream pipeline、会话仓储和认证服务
/// - 作为 axum handler 的共享状态
#[derive(Clone)]
pub struct AiHttpState {
    pub stream_pipeline: Arc<AiStreamPipeline>,
    pub llm_provider: Arc<dyn LlmProvider>,
    pub runtime_engine_mode: AgentRuntimeEngineMode,
    pub session_repository: Arc<dyn AiSessionRepository>,
    pub session_turn_repository: Arc<dyn SessionTurnRepository>,
    pub chat_turn_transaction: Arc<dyn ChatTurnTransactionPort>,
    pub session_summary_repository: Arc<dyn SessionSummaryRepository>,
    pub memory_repository: Arc<dyn MemoryRepository>,
    pub pet_resolver: Arc<AiPetResolver>,
    pub pet_context_providers: AiPetContextProviders,
    pub auth: Arc<AuthService>,
}

impl FromRef<AiHttpState> for Arc<AuthService> {
    fn from_ref(input: &AiHttpState) -> Self {
        input.auth.clone()
    }
}

/// AiPetContextProviders AI 宠物上下文 provider 集合
/// 核心职责：
/// - 聚合身份、当前饮食、储物柜线索和待确认候选 provider
/// - 控制 AiHttpState 构造参数数量，保持上下文依赖边界清晰
#[derive(Clone)]
pub struct AiPetContextProviders {
    pub identity_fact_provider: Arc<dyn PetIdentityFactProvider>,
    pub diet_fact_provider: Arc<dyn PetDietFactProvider>,
    pub food_inventory_hint_provider: Arc<dyn FoodInventoryHintProvider>,
    pub diet_confirmation_candidate_provider: Arc<dyn PetDietConfirmationCandidateProvider>,
}

impl AiPetContextProviders {
    /// new 构造宠物上下文 provider 集合
    #[must_use]
    pub fn new(
        identity_fact_provider: Arc<dyn PetIdentityFactProvider>,
        diet_fact_provider: Arc<dyn PetDietFactProvider>,
        food_inventory_hint_provider: Arc<dyn FoodInventoryHintProvider>,
        diet_confirmation_candidate_provider: Arc<dyn PetDietConfirmationCandidateProvider>,
    ) -> Self {
        Self {
            identity_fact_provider,
            diet_fact_provider,
            food_inventory_hint_provider,
            diet_confirmation_candidate_provider,
        }
    }
}

/// build_ai_router 构建 AI 路由
pub fn build_ai_router(state: AiHttpState) -> Router {
    Router::new()
        .route("/api/v1/ai/chat", post(chat::handle_chat))
        .route("/api/v1/ai/chat/stream", post(chat::handle_chat_stream))
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
        .with_state(state)
}
