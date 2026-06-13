#![allow(
    clippy::doc_markdown,
    clippy::double_must_use,
    clippy::missing_errors_doc,
    clippy::missing_panics_doc,
    clippy::needless_raw_string_hashes
)]

mod home_dashboard;
pub mod test_support;

use std::{env, sync::Arc};

use axum::Router;
use home_dashboard::{HybridHomeDashboardProvider, InMemoryHomeDashboardProvider};
use maohuoban_auth_application::auth::{AuthService, AuthServiceConfig};
use maohuoban_auth_http::auth::build_auth_router;
use maohuoban_auth_infrastructure::{
    postgres::PostgresAuthRepository,
    redis::RedisOtpChallengeStore,
    security::{Argon2PasswordCredentialService, JwtTokenIssuer},
};
use maohuoban_home_application::home::{HomeDashboardService, pet_owner_home_snapshot};
use maohuoban_home_http::home::build_home_router;
use maohuoban_legal_application::legal::LegalDocumentService;
use maohuoban_legal_http::legal::build_legal_router;
use maohuoban_legal_infrastructure::postgres::PostgresLegalDocumentRepository;
use maohuoban_pet_application::pet::PetService;
use maohuoban_pet_http::pet::build_pet_router;
use maohuoban_pet_infrastructure::postgres::PostgresPetRepository;
use redis::aio::ConnectionManager;
use sqlx::{PgPool, postgres::PgPoolOptions};
use thiserror::Error;

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
        }
    }

    #[must_use]
    pub fn local_test() -> Self {
        Self {
            server_bind_addr: "127.0.0.1:0".to_owned(),
            database_url: env::var("TEST_DATABASE_URL")
                .unwrap_or_else(|_| "postgres://fengjinyi@localhost/maohuoban".to_owned()),
            redis_url: env::var("TEST_REDIS_URL")
                .unwrap_or_else(|_| "redis://127.0.0.1:6379/15".to_owned()),
            redis_key_prefix: "maohuoban:test:auth".to_owned(),
            jwt_secret: "maohuoban-local-test-jwt-secret".to_owned(),
            access_token_ttl_seconds: 15 * 60,
            refresh_token_ttl_seconds: 180 * 24 * 60 * 60,
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

    let auth_service = Arc::new(AuthService::new(
        AuthServiceConfig::default(),
        Arc::new(otp_store),
        Arc::new(repository.clone()),
        Arc::new(password_service.clone()),
        Arc::new(repository.clone()),
        Arc::new(token_issuer.clone()),
        Arc::new(repository.clone()),
    ));
    let legal_repository = PostgresLegalDocumentRepository::new(pool.clone());
    let legal_service = Arc::new(LegalDocumentService::new(Arc::new(legal_repository)));
    let pet_repository = PostgresPetRepository::new(pool.clone());
    let pet_service = Arc::new(PetService::new(
        Arc::new(pet_repository.clone()),
        Arc::new(pet_repository.clone()),
    ));
    let home_provider = HybridHomeDashboardProvider::new(
        InMemoryHomeDashboardProvider::new(pet_owner_home_snapshot()),
        pet_service.clone(),
    );
    let home_service = Arc::new(HomeDashboardService::new(Box::new(home_provider.clone())));
    let router = build_auth_router(auth_service)
        .merge(build_legal_router(legal_service))
        .merge(build_home_router(home_service))
        .merge(build_pet_router(pet_service));

    Ok(BackendApp {
        router,
        pool,
        redis_connection,
        repository,
        password_service,
        token_issuer,
        home_provider,
        pet_repository,
    })
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
}
