#![allow(
    clippy::doc_markdown,
    clippy::double_must_use,
    clippy::missing_errors_doc,
    clippy::missing_panics_doc,
    clippy::needless_raw_string_hashes
)]

use std::{env, sync::Arc};

use axum::Router;
use chrono::{Datelike, NaiveDate, Utc};
use maohuoban_auth_application::auth::{AuthService, AuthServiceConfig};
use maohuoban_auth_http::auth::build_auth_router;
use maohuoban_auth_infrastructure::{
    postgres::PostgresAuthRepository,
    redis::RedisOtpChallengeStore,
    security::{Argon2PasswordCredentialService, JwtTokenIssuer},
};
use maohuoban_home_application::home::{
    HomeDashboardContext, HomeDashboardProvider, HomeDashboardService, HomeError, HomeResult,
    new_user_home_snapshot, pet_owner_home_snapshot,
};
use maohuoban_home_domain::home::{
    HomeDashboardSnapshot, HomeIdentity, HomeIdentityKind, HomeTimelineEvent,
    HomeTimelineEventKind, PetHeroSummary, PetSex as HomePetSex, PetSpecies as HomePetSpecies,
    PetSwitchItem,
};
use maohuoban_home_http::home::build_home_router;
use maohuoban_legal_application::legal::LegalDocumentService;
use maohuoban_legal_http::legal::build_legal_router;
use maohuoban_legal_infrastructure::postgres::PostgresLegalDocumentRepository;
use maohuoban_pet_application::pet::PetService;
use maohuoban_pet_domain::pet::{
    EventKind, PetError, PetEvent, PetProfile, PetSex as DomainPetSex,
    PetSpecies as DomainPetSpecies,
};
use maohuoban_pet_http::pet::build_pet_router;
use maohuoban_pet_infrastructure::postgres::PostgresPetRepository;
use redis::aio::ConnectionManager;
use sqlx::{PgPool, postgres::PgPoolOptions};
use thiserror::Error;
use tokio::sync::RwLock;
use uuid::Uuid;

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

/// InMemoryHomeDashboardProvider 内存首页快照提供器
/// 核心职责：
/// - 为开发和契约测试提供可替换首页快照
/// - 保持首页应用服务依赖端口而非具体数据库实现
#[derive(Clone)]
pub struct InMemoryHomeDashboardProvider {
    snapshot: Arc<RwLock<HomeDashboardSnapshot>>,
}

impl InMemoryHomeDashboardProvider {
    #[must_use]
    pub fn new(snapshot: HomeDashboardSnapshot) -> Self {
        Self {
            snapshot: Arc::new(RwLock::new(snapshot)),
        }
    }

    /// replace_snapshot 替换首页快照
    /// 核心职责：
    /// - 为测试和开发种子切换首页形态
    /// - 通过写锁保证读取和替换的一致性
    pub async fn replace_snapshot(&self, snapshot: HomeDashboardSnapshot) {
        *self.snapshot.write().await = snapshot;
    }
}

#[async_trait::async_trait]
impl HomeDashboardProvider for InMemoryHomeDashboardProvider {
    async fn get_dashboard_snapshot(
        &self,
        _context: HomeDashboardContext,
    ) -> HomeResult<HomeDashboardSnapshot> {
        Ok(self.snapshot.read().await.clone())
    }
}

/// HybridHomeDashboardProvider 混合首页快照提供器
/// 核心职责：
/// - 无用户上下文时保留开发 seed 快照
/// - 有用户上下文时读取宠物档案和事件生成真实首页聚合
#[derive(Clone)]
pub struct HybridHomeDashboardProvider {
    fallback: InMemoryHomeDashboardProvider,
    pet_service: Arc<PetService>,
}

impl HybridHomeDashboardProvider {
    #[must_use]
    pub fn new(fallback: InMemoryHomeDashboardProvider, pet_service: Arc<PetService>) -> Self {
        Self {
            fallback,
            pet_service,
        }
    }

    /// replace_snapshot 替换无上下文首页快照
    /// 核心职责：
    /// - 支持首页契约测试切换开发 seed
    /// - 不影响带用户上下文的真实聚合路径
    pub async fn replace_snapshot(&self, snapshot: HomeDashboardSnapshot) {
        self.fallback.replace_snapshot(snapshot).await;
    }

    async fn snapshot_for_user(&self, user_id: Uuid) -> HomeResult<HomeDashboardSnapshot> {
        let pets = self
            .pet_service
            .list_pet_profiles(user_id)
            .await
            .map_err(|error| to_home_error(&error))?;
        let Some(selected_pet) = pets.first() else {
            return Ok(new_user_home_snapshot());
        };

        let timeline = self
            .pet_service
            .load_pet_timeline(user_id, selected_pet.id)
            .await
            .map_err(|error| to_home_error(&error))?;

        let mut snapshot = pet_owner_home_snapshot();
        snapshot.identity = HomeIdentity {
            kind: HomeIdentityKind::PetOwner,
            display_name: "毛伙伴用户".to_owned(),
            city: None,
            verification_badge: None,
        };
        snapshot.selected_pet = Some(pet_hero_summary(selected_pet));
        snapshot.pet_switcher = pets
            .iter()
            .map(|pet| pet_switch_item(pet, pet.id == selected_pet.id))
            .collect();
        snapshot.recent_timeline = timeline
            .events
            .iter()
            .take(3)
            .map(timeline_event_summary)
            .collect();
        snapshot.partner_recommendation = None;
        snapshot.merchant_dashboard = None;
        snapshot.empty_state = None;
        snapshot.recommended_content = Vec::new();
        Ok(snapshot)
    }
}

#[async_trait::async_trait]
impl HomeDashboardProvider for HybridHomeDashboardProvider {
    async fn get_dashboard_snapshot(
        &self,
        context: HomeDashboardContext,
    ) -> HomeResult<HomeDashboardSnapshot> {
        if let Some(user_id) = context.user_id {
            return self.snapshot_for_user(user_id).await;
        }
        self.fallback.get_dashboard_snapshot(context).await
    }
}

fn pet_hero_summary(pet: &PetProfile) -> PetHeroSummary {
    PetHeroSummary {
        id: pet.id,
        name: pet.name.clone(),
        species: home_pet_species(pet.species),
        breed: pet.breed.clone().unwrap_or_else(|| "未填写品种".to_owned()),
        sex: home_pet_sex(pet.sex),
        age_text: pet_age_text(pet.birthday),
        status_text: "记录正在形成可信档案".to_owned(),
        updated_text: "档案已同步".to_owned(),
        avatar_url: None,
    }
}

fn pet_switch_item(pet: &PetProfile, is_selected: bool) -> PetSwitchItem {
    PetSwitchItem {
        id: pet.id,
        name: pet.name.clone(),
        species: home_pet_species(pet.species),
        avatar_url: None,
        is_selected,
    }
}

fn timeline_event_summary(event: &PetEvent) -> HomeTimelineEvent {
    HomeTimelineEvent {
        id: event.id,
        event_kind: home_timeline_event_kind(event),
        title: event.title.clone(),
        subtitle: event
            .summary
            .clone()
            .unwrap_or_else(|| "已记录到可信档案".to_owned()),
        occurred_text: event.occurred_at.format("%Y-%m-%d").to_string(),
    }
}

fn home_pet_species(species: DomainPetSpecies) -> HomePetSpecies {
    match species {
        DomainPetSpecies::Dog => HomePetSpecies::Dog,
        DomainPetSpecies::Cat => HomePetSpecies::Cat,
        DomainPetSpecies::Other => HomePetSpecies::Other,
    }
}

fn home_pet_sex(sex: DomainPetSex) -> HomePetSex {
    match sex {
        DomainPetSex::Female => HomePetSex::Female,
        DomainPetSex::Male => HomePetSex::Male,
        DomainPetSex::Unknown => HomePetSex::Unknown,
    }
}

fn home_timeline_event_kind(event: &PetEvent) -> HomeTimelineEventKind {
    match event.event_kind {
        EventKind::Daily | EventKind::Growth | EventKind::Memorial => HomeTimelineEventKind::Daily,
        EventKind::Health if event.event_subkind.as_deref() == Some("weight") => {
            HomeTimelineEventKind::Weight
        }
        EventKind::Health | EventKind::Hospital | EventKind::Trade => HomeTimelineEventKind::Health,
        EventKind::Merchant => HomeTimelineEventKind::Merchant,
    }
}

fn pet_age_text(birthday: Option<NaiveDate>) -> String {
    let Some(birthday) = birthday else {
        return "未填写年龄".to_owned();
    };
    let today = Utc::now().date_naive();
    if birthday > today {
        return "未填写年龄".to_owned();
    }
    let mut years = today.year() - birthday.year();
    if (today.month(), today.day()) < (birthday.month(), birthday.day()) {
        years -= 1;
    }
    if years > 0 {
        format!("{years}岁")
    } else {
        "未满1岁".to_owned()
    }
}

fn to_home_error(error: &PetError) -> HomeError {
    HomeError::Infrastructure(error.to_string())
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
    let pet_service = Arc::new(PetService::new(Arc::new(pet_repository.clone())));
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

pub mod test_support {
    use std::sync::{Arc, OnceLock};

    use chrono::{Duration, Utc};
    use maohuoban_auth_application::auth::{
        NewDeviceSession, PasswordCredentialService, SessionRepository, TokenIssuer, UserRepository,
    };
    use maohuoban_auth_domain::auth::DeviceDescriptor;
    use maohuoban_home_application::home::{
        merchant_home_snapshot, new_user_home_snapshot, pet_owner_home_snapshot,
    };
    use tokio::sync::{Mutex, OwnedMutexGuard};
    use uuid::Uuid;

    use super::{BackendApp, BackendConfig, build_backend_app};

    /// AuthTestApp 认证集成测试应用
    /// 核心职责：
    /// - 暴露可 clone 的 router 供契约测试调用
    /// - 提供数据库和 Redis 重置、测试数据种子能力
    pub struct AuthTestApp {
        app: BackendApp,
        _guard: OwnedMutexGuard<()>,
    }

    impl AuthTestApp {
        #[must_use]
        pub fn router(&self) -> axum::Router {
            self.app.router.clone()
        }

        pub async fn reset(&self) {
            sqlx::query(
                r#"
                TRUNCATE TABLE
                    pet_relationships,
                    pet_events,
                    evidence_snapshots,
                    litters,
                    pet_profiles,
                    merchant_profiles,
                    auth_audit_events,
                    device_sessions,
                    password_credentials,
                    user_identities,
                    users
                CASCADE
                "#,
            )
            .execute(&self.app.pool)
            .await
            .expect("reset auth tables");

            let mut connection = self.app.redis_connection.clone();
            redis::cmd("FLUSHDB")
                .query_async::<()>(&mut connection)
                .await
                .expect("flush test redis db");
        }

        pub async fn seed_user_with_password(&self, phone: &str, password: &str) {
            let user = self
                .app
                .repository
                .upsert_user_by_phone(phone)
                .await
                .expect("seed phone user");
            let password_hash = self
                .app
                .password_service
                .hash_password(password)
                .expect("hash seed password");
            self.app
                .repository
                .save_password_credential(user.id, &password_hash)
                .await
                .expect("save seed password");
        }

        pub async fn seed_login_session(&self, phone: &str, device_id: &str) -> SeedLoginSession {
            let user = self
                .app
                .repository
                .upsert_user_by_phone(phone)
                .await
                .expect("seed phone user");
            let refresh_token = self
                .app
                .token_issuer
                .generate_refresh_token()
                .expect("generate seed refresh token");
            let refresh_token_hash = self.app.token_issuer.hash_refresh_token(&refresh_token);
            let expires_at =
                Utc::now() + Duration::seconds(self.app.token_issuer.refresh_token_ttl_seconds());
            self.app
                .repository
                .create_device_session(NewDeviceSession {
                    session_id: Uuid::new_v4(),
                    user_id: user.id,
                    device: DeviceDescriptor {
                        device_id: device_id.to_owned(),
                        device_name: "iPhone 17 Pro".to_owned(),
                        platform: "iOS".to_owned(),
                        app_version: "1.0".to_owned(),
                    },
                    refresh_token_hash,
                    expires_at,
                })
                .await
                .expect("create seed session");

            SeedLoginSession { refresh_token }
        }

        pub async fn audit_event_count(&self) -> i64 {
            sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM auth_audit_events")
                .fetch_one(&self.app.pool)
                .await
                .expect("count auth audit events")
        }

        /// seed_pet_owner_home 设置普通用户首页快照
        /// 核心职责：
        /// - 为首页契约测试提供普通用户场景
        /// - 覆盖宠物主卡、照护、快捷动作和最近时间线
        pub async fn seed_pet_owner_home(&self) {
            self.app
                .home_provider
                .replace_snapshot(pet_owner_home_snapshot())
                .await;
        }

        /// seed_new_user_home 设置新用户首页快照
        /// 核心职责：
        /// - 为首页契约测试提供无宠物空态
        /// - 覆盖创建宠物主操作和辅助推荐内容
        pub async fn seed_new_user_home(&self) {
            self.app
                .home_provider
                .replace_snapshot(new_user_home_snapshot())
                .await;
        }

        /// seed_merchant_home 设置认证商家首页快照
        /// 核心职责：
        /// - 为首页契约测试提供机构宠物工作台
        /// - 覆盖多宠状态、窝次入口和待补记录
        pub async fn seed_merchant_home(&self) {
            self.app
                .home_provider
                .replace_snapshot(merchant_home_snapshot())
                .await;
        }
    }

    /// SeedLoginSession 测试登录会话
    /// 核心职责：
    /// - 向契约测试暴露 refresh token
    /// - 隐藏服务端 session 持久化细节
    pub struct SeedLoginSession {
        pub refresh_token: String,
    }

    pub async fn spawn_auth_test_app() -> AuthTestApp {
        let guard = auth_test_lock().lock_owned().await;
        let app = build_backend_app(BackendConfig::local_test())
            .await
            .expect("build auth test app");
        AuthTestApp { app, _guard: guard }
    }

    /// spawn_home_test_app 构建首页契约测试应用
    /// 核心职责：
    /// - 复用后端完整路由装配
    /// - 暴露首页种子快照切换能力
    pub async fn spawn_home_test_app() -> AuthTestApp {
        spawn_auth_test_app().await
    }

    fn auth_test_lock() -> Arc<Mutex<()>> {
        static LOCK: OnceLock<Arc<Mutex<()>>> = OnceLock::new();
        LOCK.get_or_init(|| Arc::new(Mutex::new(()))).clone()
    }
}
