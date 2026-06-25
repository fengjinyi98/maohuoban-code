use std::sync::{Arc, OnceLock};

use chrono::{Duration, Utc};
use maohuoban_auth_application::auth::{
    NewDeviceSession, PasswordCredentialService, SessionRepository, TokenIssuer, UserRepository,
};
use maohuoban_auth_domain::auth::DeviceDescriptor;
use maohuoban_home_application::home::{merchant_home_snapshot, new_user_home_snapshot};
use tokio::sync::{Mutex, OwnedMutexGuard};
use uuid::Uuid;

use crate::{BackendApp, BackendConfig, build_backend_app};

mod media;
mod merchant;

pub use media::MediaCleanupState;

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
        assert_test_database(&self.app.pool).await;
        sqlx::query(
            r#"
            TRUNCATE TABLE
                samecity_hospital_appointments,
                media_audit_events,
                media_cleanup_jobs,
                media_bindings,
                media_derivatives,
                media_assets,
                pet_profile_name_changes,
                pet_relationships,
                pet_events,
                evidence_snapshots,
                litters,
                pet_profiles,
                merchant_profiles,
                user_profile_field_changes,
                user_profiles,
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
        sqlx::query("ALTER SEQUENCE users_join_sequence_seq RESTART WITH 1")
            .execute(&self.app.pool)
            .await
            .expect("reset user join sequence");

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

    /// seed_active_pet_co_caretaker 写入活跃共管关系
    /// 核心职责：
    /// - 为宠物关系授权契约测试准备 co_caretaker 关系
    /// - 避免测试绕过真实 HTTP 鉴权链路
    pub async fn seed_active_pet_co_caretaker(&self, pet_id: &str, user_id: &str) {
        let pet_id = Uuid::parse_str(pet_id).expect("pet id");
        let user_id = Uuid::parse_str(user_id).expect("user id");
        sqlx::query(
            r#"
            INSERT INTO pet_guardians (
                id,
                pet_id,
                guardian_type,
                guardian_user_id,
                role,
                status,
                started_at
            )
            VALUES ($1, $2, 'user', $3, 'co_caretaker', 'active', now())
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(pet_id)
        .bind(user_id)
        .execute(&self.app.pool)
        .await
        .expect("seed active pet co caretaker");
    }

    /// active_microchip_identifier_count 统计活跃芯片标识
    /// 核心职责：
    /// - 验证芯片写入是否进入外部标识表
    /// - 区分重复提交与新写入行为
    pub async fn active_microchip_identifier_count(&self, pet_id: &str, microchip: &str) -> i64 {
        let pet_id = Uuid::parse_str(pet_id).expect("pet id");
        sqlx::query_scalar::<_, i64>(
            r#"
            SELECT COUNT(*)
            FROM pet_external_identifiers
            WHERE pet_id = $1
              AND identifier_type = 'microchip'
              AND identifier_value = $2
              AND status = 'active'
            "#,
        )
        .bind(pet_id)
        .bind(microchip)
        .fetch_one(&self.app.pool)
        .await
        .expect("count active microchip identifiers")
    }

    /// microchip_identifier_status_count 统计指定状态芯片标识
    /// 核心职责：
    /// - 验证冲突芯片是否进入 disputed 生命周期
    /// - 支持 identity context 契约测试读取状态准备
    pub async fn microchip_identifier_status_count(
        &self,
        pet_id: &str,
        microchip: &str,
        status: &str,
    ) -> i64 {
        let pet_id = Uuid::parse_str(pet_id).expect("pet id");
        sqlx::query_scalar::<_, i64>(
            r#"
            SELECT COUNT(*)
            FROM pet_external_identifiers
            WHERE pet_id = $1
              AND identifier_type = 'microchip'
              AND identifier_value = $2
              AND status = $3
            "#,
        )
        .bind(pet_id)
        .bind(microchip)
        .bind(status)
        .fetch_one(&self.app.pool)
        .await
        .expect("count microchip identifiers by status")
    }

    /// pet_profile_microchip_projection 读取主表芯片兼容投影
    /// 核心职责：
    /// - 验证新写入路径停止依赖 pet_profiles.microchip_number
    /// - 保持测试只读取 Phase 1 兼容字段
    pub async fn pet_profile_microchip_projection(&self, pet_id: &str) -> Option<String> {
        let pet_id = Uuid::parse_str(pet_id).expect("pet id");
        sqlx::query_scalar::<_, Option<String>>(
            r#"
            SELECT microchip_number
            FROM pet_profiles
            WHERE id = $1
            "#,
        )
        .bind(pet_id)
        .fetch_one(&self.app.pool)
        .await
        .expect("read profile microchip projection")
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

    /// seed_same_litter_relationship 写入同窝关系测试数据
    /// 核心职责：
    /// - 为首页今日伙伴推荐准备显式关系边
    /// - 保持推荐契约测试不依赖商家完整窝次流程
    pub async fn seed_same_litter_relationship(&self, subject_pet_id: &str, related_pet_id: &str) {
        let subject_pet_id = Uuid::parse_str(subject_pet_id).expect("subject pet id");
        let related_pet_id = Uuid::parse_str(related_pet_id).expect("related pet id");
        sqlx::query(
            r#"
            INSERT INTO pet_relationships (
                id,
                subject_pet_id,
                related_pet_id,
                relationship_kind,
                source_kind
            )
            VALUES ($1, $2, $3, 'same_litter', 'system_derived')
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(subject_pet_id)
        .bind(related_pet_id)
        .execute(&self.app.pool)
        .await
        .expect("seed same litter relationship");
    }
}

/// SeedLoginSession 测试登录会话
/// 核心职责：
/// - 向契约测试暴露 refresh token
/// - 隐藏服务端 session 持久化细节
pub struct SeedLoginSession {
    pub refresh_token: String,
}

async fn assert_test_database(pool: &sqlx::PgPool) {
    let database_name = sqlx::query_scalar::<_, String>("SELECT current_database()")
        .fetch_one(pool)
        .await
        .expect("read current database");
    assert!(
        database_name.ends_with("_test") || database_name.contains("test"),
        "refuse to reset non-test database: {database_name}"
    );
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
