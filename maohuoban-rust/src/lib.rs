pub mod diagnostics;
mod home_dashboard;
mod home_event_projection;
mod infrastructure;
mod media_content;
pub mod test_support;
pub use infrastructure::agent_followup_planner;
pub use infrastructure::agent_followup_scheduler;

use std::{env, sync::Arc};

use async_trait::async_trait;
use axum::{Router, middleware};
use diagnostics::{
    build_diagnostics_ingest_router, diagnostics_ingest_config_from_env, record_http_network,
};
use home_dashboard::{HybridHomeDashboardProvider, InMemoryHomeDashboardProvider};
use maohuoban_ai_application::ai::pet_resolver::AiPetResolver;
use maohuoban_ai_application::ai::runtime::AgentRuntimeEngineMode;
use maohuoban_ai_http::ai::router::{
    AiHttpState, AiPetContextProviderParts, AiPetContextProviders, build_ai_chat_router,
    build_ai_confirmation_task_router, build_ai_history_router, build_ai_router_state,
};
use maohuoban_ai_infrastructure::provider::LlmProviderRegistryConfig;
use maohuoban_ai_infrastructure::repository::{
    PostgresAiSessionRepository, PostgresChatTurnTransaction, PostgresMemoryRepository,
    PostgresSessionSummaryRepository, PostgresSessionTurnRepository,
};
use maohuoban_auth_application::auth::{
    AuthService, AuthServiceConfig, AuthServiceDependencies, UserProfileInitializer,
};
use maohuoban_auth_domain::auth::{AuthResult, AuthUser};
use maohuoban_auth_http::auth::{
    build_auth_public_router, build_auth_session_protected_router,
    build_auth_user_protected_router,
    extractor::{AuthMiddlewareState, require_authenticated_session, require_authenticated_user},
};
use maohuoban_auth_infrastructure::{
    postgres::PostgresAuthRepository,
    redis::RedisOtpChallengeStore,
    security::{Argon2PasswordCredentialService, JwtTokenIssuer},
};
use maohuoban_home_application::home::{HomeDashboardService, new_user_home_snapshot};
use maohuoban_home_http::home::{HomeRealtimeHub, build_home_router};
use maohuoban_legal_application::legal::LegalDocumentService;
use maohuoban_legal_http::legal::build_legal_router;
use maohuoban_legal_infrastructure::postgres::PostgresLegalDocumentRepository;
use maohuoban_pet_application::pet::PetService;
use maohuoban_pet_http::pet::build_pet_router;
use maohuoban_pet_infrastructure::postgres::{
    PostgresAgentConfirmationTaskRepository, PostgresDietRepository,
    PostgresFoodInventoryRepository, PostgresPetAlbumRepository, PostgresPetRepository,
};
use maohuoban_profile_application::profile::ProfileService;
use maohuoban_profile_http::profile::build_profile_router;
use maohuoban_profile_infrastructure::postgres::PostgresProfileRepository;
use maohuoban_recommendation_application::recommendation::RecommendationService;
use maohuoban_recommendation_infrastructure::postgres::PostgresRecommendationRepository;
use maohuoban_samecity_application::samecity::SameCityService;
use maohuoban_samecity_http::samecity::build_samecity_router;
use maohuoban_samecity_infrastructure::postgres::PostgresSameCityRepository;
use media_content::build_media_content_router;
use redis::aio::ConnectionManager;
use sqlx::{PgPool, postgres::PgPoolOptions};
use thiserror::Error;

use crate::infrastructure::ai::{
    PetServiceAbnormalEpisodeFactProvider, PetServiceAbnormalFollowupPlanProvider,
    PetServiceAuthorizedPetCatalog, PetServiceDietConfirmationCandidateProvider,
    PetServiceDietFactProvider, PetServiceFoodInventoryHintProvider,
    PetServiceHealthQuickFactProvider, PetServiceIdentityFactProvider,
    PetServiceObservationWriteProvider,
};

/// `BackendConfig` 后端启动配置
/// 核心职责：
/// - 汇总认证服务所需外部资源地址和安全配置
/// - 为本地开发、测试、生产装配提供统一入口
#[derive(Debug, Clone)]
pub struct BackendConfig {
    pub server_bind_addr: String,
    pub database_url: String,
    pub redis_url: String,
    pub redis_key_prefix: String,
    pub jwt_secret: String,
    pub access_token_ttl_seconds: i64,
    pub refresh_token_ttl_seconds: i64,
    pub diagnostics_ingest_enabled: bool,
    pub ai_llm_provider_config: LlmProviderRegistryConfig,
    pub ai_runtime_engine_mode: AgentRuntimeEngineMode,
}

impl BackendConfig {
    #[must_use]
    pub fn from_env() -> Self {
        let _ = dotenvy::dotenv();
        Self {
            server_bind_addr: env::var("SERVER_BIND_ADDR")
                .unwrap_or_else(|_| "0.0.0.0:8080".to_owned()),
            database_url: env::var("DATABASE_URL")
                .unwrap_or_else(|_| "postgres://fengjinyi@localhost/maohuoban".to_owned()),
            redis_url: env::var("REDIS_URL")
                .unwrap_or_else(|_| "redis://127.0.0.1:6379/0".to_owned()),
            redis_key_prefix: env::var("REDIS_KEY_PREFIX")
                .unwrap_or_else(|_| "maohuoban:auth".to_owned()),
            jwt_secret: env::var("JWT_SECRET").unwrap_or_else(|_| {
                "maohuoban-local-development-jwt-secret-change-before-production".to_owned()
            }),
            access_token_ttl_seconds: 15 * 60,
            refresh_token_ttl_seconds: 180 * 24 * 60 * 60,
            diagnostics_ingest_enabled: Self::diagnostics_ingest_enabled_from_env_value(
                env::var("MAOHUOBAN_DIAGNOSTICS_INGEST_ENABLED")
                    .ok()
                    .as_deref(),
            ),
            ai_llm_provider_config: LlmProviderRegistryConfig::from_env(),
            ai_runtime_engine_mode: AgentRuntimeEngineMode::SelfHosted,
        }
    }

    #[must_use]
    pub fn diagnostics_ingest_enabled_from_env_value(value: Option<&str>) -> bool {
        value.is_none_or(|value| value != "0" && !value.eq_ignore_ascii_case("false"))
    }

    #[must_use]
    pub fn local_test() -> Self {
        Self {
            server_bind_addr: "127.0.0.1:0".to_owned(),
            database_url: env::var("TEST_DATABASE_URL")
                .unwrap_or_else(|_| "postgres://fengjinyi@localhost/maohuoban_test".to_owned()),
            redis_url: env::var("TEST_REDIS_URL")
                .unwrap_or_else(|_| "redis://127.0.0.1:6379/15".to_owned()),
            redis_key_prefix: "maohuoban:test:auth".to_owned(),
            jwt_secret: "maohuoban-local-test-jwt-secret".to_owned(),
            access_token_ttl_seconds: 15 * 60,
            refresh_token_ttl_seconds: 180 * 24 * 60 * 60,
            diagnostics_ingest_enabled: true,
            ai_llm_provider_config: LlmProviderRegistryConfig::default(),
            ai_runtime_engine_mode: AgentRuntimeEngineMode::SelfHosted,
        }
    }
}

/// `BackendApp` 后端应用实例
/// 核心职责：
/// - 暴露 axum router 给运行时或测试
/// - 保留基础设施资源用于测试数据准备
#[derive(Clone)]
pub struct BackendApp {
    pub router: Router,
    pub pool: PgPool,
    pub redis_connection: ConnectionManager,
    pub repository: PostgresAuthRepository,
    pub password_service: Argon2PasswordCredentialService,
    pub token_issuer: JwtTokenIssuer,
    pub home_provider: HybridHomeDashboardProvider,
    pub pet_repository: PostgresPetRepository,
    pub profile_repository: PostgresProfileRepository,
    pub recommendation_repository: PostgresRecommendationRepository,
    pub samecity_repository: PostgresSameCityRepository,
    pub ai_session_repository: PostgresAiSessionRepository,
    pub ai_session_turn_repository: PostgresSessionTurnRepository,
    pub home_realtime_hub: HomeRealtimeHub,
}

/// `build_backend_app` 构建后端应用
/// 核心职责：
/// - 连接 `PostgreSQL` 和 Redis
/// - 运行数据库迁移并装配认证、法务文档分层服务
///
/// # Errors
///
/// 当数据库连接、迁移、Redis 连接或诊断路由装配失败时返回错误。
pub async fn build_backend_app(config: BackendConfig) -> Result<BackendApp, BackendError> {
    let pool = PgPoolOptions::new()
        .max_connections(8)
        .connect(&config.database_url)
        .await?;
    sqlx::migrate!("./migrations").run(&pool).await?;

    let redis_client = redis::Client::open(config.redis_url.as_str())?;
    let redis_connection = redis_client.get_connection_manager().await?;

    let profile_repository = PostgresProfileRepository::new(pool.clone());
    let profile_service = Arc::new(ProfileService::new(Arc::new(profile_repository.clone())));
    let AuthComponents {
        repository,
        password_service,
        token_issuer,
        service: auth_service,
    } = build_auth_components(&pool, &redis_connection, &config, profile_service.clone());
    let legal_repository = PostgresLegalDocumentRepository::new(pool.clone());
    let legal_service = Arc::new(LegalDocumentService::new(Arc::new(legal_repository)));
    let pet_repository = PostgresPetRepository::new(pool.clone());
    let pet_album_repository = PostgresPetAlbumRepository::new(pool.clone());
    let food_inventory_repository = PostgresFoodInventoryRepository::new(pool.clone());
    let diet_repository = PostgresDietRepository::new(pool.clone());
    let confirmation_task_repository = PostgresAgentConfirmationTaskRepository::new(pool.clone());
    let pet_service = Arc::new(PetService::new(
        Arc::new(pet_repository.clone()),
        Arc::new(pet_album_repository),
        Arc::new(pet_repository.clone()),
        Arc::new(food_inventory_repository),
        Arc::new(diet_repository),
    ));
    let recommendation_repository = PostgresRecommendationRepository::new(pool.clone());
    let recommendation_service = Arc::new(RecommendationService::new(Arc::new(
        recommendation_repository.clone(),
    )));
    let samecity_repository = PostgresSameCityRepository::new(pool.clone());
    let samecity_service = Arc::new(SameCityService::new(Arc::new(samecity_repository.clone())));
    let home_provider = HybridHomeDashboardProvider::new(
        InMemoryHomeDashboardProvider::new(new_user_home_snapshot()),
        pet_service.clone(),
        recommendation_service,
    );
    let home_service = Arc::new(HomeDashboardService::new(Box::new(home_provider.clone())));
    let home_realtime_hub = HomeRealtimeHub::new();
    let ai_session_repository = PostgresAiSessionRepository::new(pool.clone());
    let ai_session_turn_repository = PostgresSessionTurnRepository::new(pool.clone());
    let ai_chat_turn_transaction = PostgresChatTurnTransaction::new(pool.clone());
    let ai_http_state = build_ai_http_state(
        &config.ai_llm_provider_config,
        config.ai_runtime_engine_mode,
        &pet_service,
        AiHttpRepositories {
            session_repository: ai_session_repository.clone(),
            session_turn_repository: ai_session_turn_repository.clone(),
            chat_turn_transaction: ai_chat_turn_transaction,
        },
        &pool,
        Arc::new(confirmation_task_repository),
    );
    let router = build_backend_router(BackendRouterParts {
        config: &config,
        pool: &pool,
        auth_service: auth_service.clone(),
        profile_service: profile_service.clone(),
        legal_service,
        home_service,
        home_realtime_hub: home_realtime_hub.clone(),
        pet_service,
        samecity_service,
        ai_http_state,
    })?;

    Ok(BackendApp {
        router,
        pool,
        redis_connection,
        repository,
        password_service,
        token_issuer,
        home_provider,
        pet_repository,
        profile_repository,
        recommendation_repository,
        samecity_repository,
        ai_session_repository,
        ai_session_turn_repository,
        home_realtime_hub,
    })
}

/// `BackendRouterParts` 后端路由装配输入
/// 核心职责：
/// - 汇总根路由所需应用服务与基础设施句柄
/// - 控制 `build_backend_router` 参数数量
struct BackendRouterParts<'a> {
    config: &'a BackendConfig,
    pool: &'a PgPool,
    auth_service: Arc<AuthService>,
    profile_service: Arc<ProfileService>,
    legal_service: Arc<LegalDocumentService>,
    home_service: Arc<HomeDashboardService>,
    home_realtime_hub: HomeRealtimeHub,
    pet_service: Arc<PetService>,
    samecity_service: Arc<SameCityService>,
    ai_http_state: AiHttpState,
}

/// `build_backend_router` 装配后端根路由
/// 核心职责：
/// - 合并公开、受保护、AI、媒体和诊断路由
/// - 安装全局网络诊断记录中间件
fn build_backend_router(parts: BackendRouterParts<'_>) -> Result<Router, BackendError> {
    let auth_middleware_state = AuthMiddlewareState::new(parts.auth_service.clone());
    let auth_routes = build_auth_routes(
        parts.auth_service,
        parts.profile_service.clone(),
        auth_middleware_state.clone(),
    );
    let protected_user_routes = build_protected_user_routes(
        parts.home_service,
        parts.home_realtime_hub,
        parts.profile_service,
        parts.pet_service,
        parts.samecity_service,
        auth_middleware_state.clone(),
    );
    let ai_routes = build_authenticated_ai_routes(auth_middleware_state, parts.ai_http_state);
    let mut router = auth_routes
        .merge(build_legal_router(parts.legal_service))
        .merge(build_media_content_router(parts.pool.clone()))
        .merge(protected_user_routes)
        .merge(ai_routes);
    if parts.config.diagnostics_ingest_enabled {
        router = router.merge(build_diagnostics_ingest_router(
            diagnostics_ingest_config_from_env(),
        )?);
    }
    Ok(router.layer(axum::middleware::from_fn(record_http_network)))
}

/// `AuthComponents` 认证服务装配结果
/// 核心职责：
/// - 聚合认证仓储、密码服务、令牌签发器和应用服务
/// - 保留 `BackendApp` 测试访问所需基础设施句柄
struct AuthComponents {
    repository: PostgresAuthRepository,
    password_service: Argon2PasswordCredentialService,
    token_issuer: JwtTokenIssuer,
    service: Arc<AuthService>,
}

/// `build_auth_components` 装配认证服务依赖
/// 核心职责：
/// - 基于数据库、Redis 和配置创建认证应用服务
/// - 将用户 profile 初始化器注入注册/登录流程
fn build_auth_components(
    pool: &PgPool,
    redis_connection: &ConnectionManager,
    config: &BackendConfig,
    profile_service: Arc<ProfileService>,
) -> AuthComponents {
    let repository = PostgresAuthRepository::new(pool.clone());
    let otp_store =
        RedisOtpChallengeStore::new(redis_connection.clone(), config.redis_key_prefix.clone());
    let password_service = Argon2PasswordCredentialService;
    let token_issuer = JwtTokenIssuer::new(
        config.jwt_secret.clone(),
        config.access_token_ttl_seconds,
        config.refresh_token_ttl_seconds,
    );
    let auth_profile_initializer = AuthProfileInitializer::new(profile_service);
    let service = Arc::new(AuthService::new(
        AuthServiceConfig::default(),
        AuthServiceDependencies {
            otp_store: Arc::new(otp_store),
            users: Arc::new(repository.clone()),
            passwords: Arc::new(password_service.clone()),
            sessions: Arc::new(repository.clone()),
            tokens: Arc::new(token_issuer.clone()),
            events: Arc::new(repository.clone()),
            profiles: Arc::new(auth_profile_initializer),
        },
    ));

    AuthComponents {
        repository,
        password_service,
        token_issuer,
        service,
    }
}

/// `build_auth_routes` 装配认证相关路由
/// 核心职责：
/// - 合并公开认证路由、用户认证路由和 session 认证路由
/// - 在受保护认证路由上安装对应认证中间件
fn build_auth_routes(
    auth_service: Arc<AuthService>,
    profile_service: Arc<ProfileService>,
    auth_middleware_state: AuthMiddlewareState,
) -> Router {
    build_auth_public_router(auth_service.clone(), profile_service.clone())
        .merge(
            build_auth_user_protected_router(auth_service.clone(), profile_service.clone())
                .route_layer(middleware::from_fn_with_state(
                    auth_middleware_state.clone(),
                    require_authenticated_user,
                )),
        )
        .merge(
            build_auth_session_protected_router(auth_service, profile_service).route_layer(
                middleware::from_fn_with_state(
                    auth_middleware_state,
                    require_authenticated_session,
                ),
            ),
        )
}

/// `build_protected_user_routes` 装配用户级受保护业务路由
/// 核心职责：
/// - 合并首页、用户资料、宠物和同城业务路由
/// - 统一安装用户认证中间件
fn build_protected_user_routes(
    home_service: Arc<HomeDashboardService>,
    home_realtime_hub: HomeRealtimeHub,
    profile_service: Arc<ProfileService>,
    pet_service: Arc<PetService>,
    samecity_service: Arc<SameCityService>,
    auth_middleware_state: AuthMiddlewareState,
) -> Router {
    build_home_router(home_service, home_realtime_hub)
        .merge(build_profile_router(profile_service))
        .merge(build_pet_router(pet_service))
        .merge(build_samecity_router(samecity_service))
        .route_layer(middleware::from_fn_with_state(
            auth_middleware_state,
            require_authenticated_user,
        ))
}

/// `build_authenticated_ai_routes` 装配 AI 认证路由
/// 核心职责：
/// - 为聊天流路由安装 AI 专用认证和请求快照中间件
/// - 为历史路由安装普通用户认证中间件并注入 AI 状态
fn build_authenticated_ai_routes(
    auth_middleware_state: AuthMiddlewareState,
    ai_http_state: AiHttpState,
) -> Router {
    let ai_chat_routes = build_ai_chat_router()
        .route_layer(middleware::from_fn_with_state(
            auth_middleware_state.clone(),
            maohuoban_ai_http::ai::router::require_ai_chat_auth,
        ))
        .route_layer(middleware::from_fn(
            maohuoban_ai_http::ai::router::snapshot_ai_chat_request,
        ));
    let ai_history_routes = build_ai_history_router().route_layer(middleware::from_fn_with_state(
        auth_middleware_state.clone(),
        require_authenticated_user,
    ));
    let ai_confirmation_task_routes = build_ai_confirmation_task_router().route_layer(
        middleware::from_fn_with_state(auth_middleware_state, require_authenticated_user),
    );
    build_ai_router_state(
        ai_chat_routes
            .merge(ai_history_routes)
            .merge(ai_confirmation_task_routes),
        ai_http_state,
    )
}

/// `AiHttpRepositories` AI HTTP 仓储集合
/// 核心职责：
/// - 聚合 session、turn 和事务端口的仓储实现
/// - 控制 `build_ai_http_state` 参数数量
struct AiHttpRepositories {
    session_repository: PostgresAiSessionRepository,
    session_turn_repository: PostgresSessionTurnRepository,
    chat_turn_transaction: PostgresChatTurnTransaction,
}

/// `build_ai_http_state` 装配 AI HTTP 状态
/// 核心职责：
/// - 构建 LLM Provider 和宠物上下文 provider
/// - 保持 `build_backend_app` 的服务装配流程可读
fn build_ai_http_state(
    provider_config: &LlmProviderRegistryConfig,
    runtime_engine_mode: AgentRuntimeEngineMode,
    pet_service: &Arc<PetService>,
    repos: AiHttpRepositories,
    ai_session_pool: &sqlx::PgPool,
    confirmation_tasks: Arc<dyn maohuoban_pet_application::pet::AgentConfirmationTaskRepository>,
) -> AiHttpState {
    let ai_llm_provider =
        infrastructure::ai::build_ai_llm_provider_from_provider_config(provider_config);
    let ai_pet_resolver = Arc::new(AiPetResolver::new(PetServiceAuthorizedPetCatalog::new(
        Arc::clone(pet_service),
    )));

    AiHttpState {
        llm_provider: ai_llm_provider,
        runtime_engine_mode,
        session_repository: Arc::new(repos.session_repository)
            as Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
        session_turn_repository: Arc::new(repos.session_turn_repository)
            as Arc<dyn maohuoban_ai_application::ai::ports::SessionTurnRepository>,
        chat_turn_transaction: Arc::new(repos.chat_turn_transaction)
            as Arc<dyn maohuoban_ai_application::ai::ports::ChatTurnTransactionPort>,
        session_summary_repository: Arc::new(PostgresSessionSummaryRepository::new(
            ai_session_pool.clone(),
        ))
            as Arc<dyn maohuoban_ai_application::ai::ports::SessionSummaryRepository>,
        memory_repository: Arc::new(PostgresMemoryRepository::new(ai_session_pool.clone()))
            as Arc<dyn maohuoban_ai_application::ai::ports::MemoryRepository>,
        pet_resolver: ai_pet_resolver,
        pet_context_providers: AiPetContextProviders::new(AiPetContextProviderParts {
            identity_fact_provider: Arc::new(PetServiceIdentityFactProvider::new(Arc::clone(
                pet_service,
            ))),
            abnormal_episode_fact_provider: Arc::new(PetServiceAbnormalEpisodeFactProvider::new(
                Arc::clone(pet_service),
            )),
            diet_fact_provider: Arc::new(PetServiceDietFactProvider::new(Arc::clone(pet_service))),
            health_quick_fact_provider: Arc::new(PetServiceHealthQuickFactProvider::new(
                Arc::clone(pet_service),
            )),
            food_inventory_hint_provider: Arc::new(PetServiceFoodInventoryHintProvider::new(
                Arc::clone(pet_service),
            )),
            diet_confirmation_candidate_provider: Arc::new(
                PetServiceDietConfirmationCandidateProvider::new(Arc::clone(pet_service)),
            ),
            observation_write_provider: Arc::new(PetServiceObservationWriteProvider::new(
                Arc::clone(pet_service),
                confirmation_tasks.clone(),
            )),
            abnormal_followup_plan_provider: Arc::new(PetServiceAbnormalFollowupPlanProvider::new(
                Arc::clone(pet_service),
            )),
        }),
        observation_write_provider: Arc::new(PetServiceObservationWriteProvider::new(
            Arc::clone(pet_service),
            confirmation_tasks.clone(),
        )),
        confirmation_task_repository: confirmation_tasks,
    }
}

/// `AuthProfileInitializer` 认证资料初始化适配器
/// 核心职责：
/// - 将认证应用层端口转接到 `ProfileService`
/// - 保持认证域不依赖资料持久化实现
#[derive(Clone)]
struct AuthProfileInitializer {
    profile: Arc<ProfileService>,
}

impl AuthProfileInitializer {
    const fn new(profile: Arc<ProfileService>) -> Self {
        Self { profile }
    }
}

#[async_trait]
impl UserProfileInitializer for AuthProfileInitializer {
    async fn ensure_default_profile(&self, user: &AuthUser) -> AuthResult<()> {
        self.profile
            .ensure_default_profile(user.id)
            .await
            .map(|_| ())
            .map_err(|error| {
                maohuoban_auth_domain::auth::AuthError::Infrastructure(error.to_string())
            })
    }
}

/// `BackendError` 后端启动错误
/// 核心职责：
/// - 汇总外部资源连接和迁移失败
/// - 让入口层用统一错误类型终止启动
#[derive(Debug, Error)]
pub enum BackendError {
    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),
    #[error("migration error: {0}")]
    Migration(#[from] sqlx::migrate::MigrateError),
    #[error("redis error: {0}")]
    Redis(#[from] redis::RedisError),
    #[error("diagnostics error: {0}")]
    Diagnostics(#[from] maohuoban_diagnostics::DiagnosticsError),
}
