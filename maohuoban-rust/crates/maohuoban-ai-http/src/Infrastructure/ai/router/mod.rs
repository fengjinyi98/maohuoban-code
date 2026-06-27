//! router AI HTTP 路由
//! 核心职责：
//! - 承载 /api/v1/ai/chat、/api/v1/ai/chat/stream、历史接口的 HTTP DTO 和路由
//! - 用户身份只来自后端 token，不信任请求体 actor_user_id 字段

mod auth;
mod chat;
mod history;

use std::sync::Arc;

use axum::{Router, routing::post};
use maohuoban_ai_application::ai::pet_resolver::AiPetResolver;
use maohuoban_ai_application::ai::ports::{
    AiSessionRepository, FoodInventoryHintProvider, PetDietFactProvider, PetIdentityFactProvider,
};
use maohuoban_ai_application::ai::stream::AiStreamPipeline;
use maohuoban_auth_application::auth::AuthService;

/// AiHttpState AI HTTP 状态
/// 核心职责：
/// - 持有 AI stream pipeline、会话仓储和认证服务
/// - 作为 axum handler 的共享状态
#[derive(Clone)]
pub struct AiHttpState {
    pub stream_pipeline: Arc<AiStreamPipeline>,
    pub session_repository: Arc<dyn AiSessionRepository>,
    pub pet_resolver: Arc<AiPetResolver>,
    pub identity_fact_provider: Arc<dyn PetIdentityFactProvider>,
    pub diet_fact_provider: Arc<dyn PetDietFactProvider>,
    pub food_inventory_hint_provider: Arc<dyn FoodInventoryHintProvider>,
    pub auth: Arc<AuthService>,
}

impl AiHttpState {
    /// new 构造 AI HTTP 状态
    #[must_use]
    pub fn new(
        stream_pipeline: Arc<AiStreamPipeline>,
        session_repository: Arc<dyn AiSessionRepository>,
        pet_resolver: Arc<AiPetResolver>,
        identity_fact_provider: Arc<dyn PetIdentityFactProvider>,
        diet_fact_provider: Arc<dyn PetDietFactProvider>,
        food_inventory_hint_provider: Arc<dyn FoodInventoryHintProvider>,
        auth: Arc<AuthService>,
    ) -> Self {
        Self {
            stream_pipeline,
            session_repository,
            pet_resolver,
            identity_fact_provider,
            diet_fact_provider,
            food_inventory_hint_provider,
            auth,
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
            axum::routing::get(history::handle_list_sessions),
        )
        .route(
            "/api/v1/ai/chat-sessions/{id}/messages",
            axum::routing::get(history::handle_get_session_messages),
        )
        .with_state(state)
}
