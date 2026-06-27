#![allow(
    clippy::doc_markdown,
    clippy::double_must_use,
    clippy::missing_errors_doc,
    clippy::missing_panics_doc,
    clippy::needless_raw_string_hashes
)]

#[path = "Infrastructure/ai_pet_catalog.rs"]
mod ai_pet_catalog;
#[path = "Infrastructure/ai_provider.rs"]
mod ai_provider;
pub mod diagnostics;
mod home_dashboard;
mod home_event_projection;
mod media_content;
pub mod test_support;

use std::{env, sync::Arc};

use async_trait::async_trait;
use axum::Router;
use diagnostics::{
    build_diagnostics_ingest_router, diagnostics_ingest_config_from_env, record_http_network,
};
use home_dashboard::{HybridHomeDashboardProvider, InMemoryHomeDashboardProvider};
use maohuoban_ai_application::ai::pet_resolver::AiPetResolver;
use maohuoban_ai_http::ai::router::{AiHttpState, build_ai_router};
use maohuoban_ai_infrastructure::repository::PostgresAiSessionRepository;
use maohuoban_auth_application::auth::{
    AuthService, AuthServiceConfig, AuthServiceDependencies, UserProfileInitializer,
};
use maohuoban_auth_domain::auth::{AuthResult, AuthUser};
use maohuoban_auth_http::auth::build_auth_router;
use maohuoban_auth_infrastructure::{
    postgres::PostgresAuthRepository,
    redis::RedisOtpChallengeStore,
    security::{Argon2PasswordCredentialService, JwtTokenIssuer},
};
use maohuoban_home_application::home::{HomeDashboardService, new_user_home_snapshot};
use maohuoban_home_http::home::build_home_router;
use maohuoban_legal_application::legal::LegalDocumentService;
use maohuoban_legal_http::legal::build_legal_router;
use maohuoban_legal_infrastructure::postgres::PostgresLegalDocumentRepository;
use maohuoban_pet_application::pet::PetService;
use maohuoban_pet_http::pet::build_pet_router;
use maohuoban_pet_infrastructure::postgres::{
    PostgresDietRepository, PostgresFoodInventoryRepository, PostgresPetRepository,
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

use crate::ai_pet_catalog::PetServiceAuthorizedPetCatalog;

/// BackendConfig 后端启动配置
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
    pub ai_llm_provider_config:
        Option<maohuoban_ai_infrastructure::provider::OpenAiCompatibleConfig>,
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
            ai_llm_provider_config:
                maohuoban_ai_infrastructure::provider::OpenAiCompatibleConfig::from_env(),
        }
    }

    #[must_use]
    pub fn diagnostics_ingest_enabled_from_env_value(value: Option<&str>) -> bool {
        value.is_some_and(|value| value != "0" && !value.eq_ignore_ascii_case("false"))
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
            ai_llm_provider_config: None,
        }
    }
}

/// BackendApp 后端应用实例
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
}

/// build_backend_app 构建后端应用
/// 核心职责：
/// - 连接 PostgreSQL 和 Redis
/// - 运行数据库迁移并装配认证、法务文档分层服务
pub async fn build_backend_app(config: BackendConfig) -> Result<BackendApp, BackendError> {
    let pool = PgPoolOptions::new()
        .max_connections(8)
        .connect(&config.database_url)
        .await?;
    sqlx::migrate!("./migrations").run(&pool).await?;

    let redis_client = redis::Client::open(config.redis_url.as_str())?;
    let redis_connection = redis_client.get_connection_manager().await?;

    let repository = PostgresAuthRepository::new(pool.clone());
    let otp_store =
        RedisOtpChallengeStore::new(redis_connection.clone(), config.redis_key_prefix.clone());
    let password_service = Argon2PasswordCredentialService;
    let token_issuer = JwtTokenIssuer::new(
        config.jwt_secret,
        config.access_token_ttl_seconds,
        config.refresh_token_ttl_seconds,
    );
    let profile_repository = PostgresProfileRepository::new(pool.clone());
    let profile_service = Arc::new(ProfileService::new(Arc::new(profile_repository.clone())));
    let auth_profile_initializer = AuthProfileInitializer::new(profile_service.clone());

    let auth_service = Arc::new(AuthService::new(
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
    let legal_repository = PostgresLegalDocumentRepository::new(pool.clone());
    let legal_service = Arc::new(LegalDocumentService::new(Arc::new(legal_repository)));
    let pet_repository = PostgresPetRepository::new(pool.clone());
    let food_inventory_repository = PostgresFoodInventoryRepository::new(pool.clone());
    let diet_repository = PostgresDietRepository::new(pool.clone());
    let pet_service = Arc::new(PetService::new(
        Arc::new(pet_repository.clone()),
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
    let ai_session_repository = PostgresAiSessionRepository::new(pool.clone());
    let ai_stream_pipeline = Arc::new(ai_provider::build_ai_stream_pipeline_from_provider_config(
        config.ai_llm_provider_config,
    ));
    let ai_pet_resolver = Arc::new(AiPetResolver::new(PetServiceAuthorizedPetCatalog::new(
        pet_service.clone(),
    )));
    let ai_http_state = AiHttpState::new(
        ai_stream_pipeline,
        Arc::new(ai_session_repository.clone())
            as Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
        ai_pet_resolver,
        auth_service.clone(),
    );
    let mut router = build_auth_router(auth_service.clone(), profile_service.clone())
        .merge(build_legal_router(legal_service))
        .merge(build_home_router(home_service, auth_service.clone()))
        .merge(build_media_content_router(pool.clone()))
        .merge(build_profile_router(profile_service, auth_service.clone()))
        .merge(build_pet_router(pet_service, auth_service.clone()))
        .merge(build_samecity_router(samecity_service, auth_service))
        .merge(build_ai_router(ai_http_state));
    if config.diagnostics_ingest_enabled {
        router = router.merge(build_diagnostics_ingest_router(
            diagnostics_ingest_config_from_env(),
        )?);
    }
    let router = router.layer(axum::middleware::from_fn(record_http_network));

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
    })
}

/// AuthProfileInitializer 认证资料初始化适配器
/// 核心职责：
/// - 将认证应用层端口转接到 ProfileService
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

/// BackendError 后端启动错误
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
