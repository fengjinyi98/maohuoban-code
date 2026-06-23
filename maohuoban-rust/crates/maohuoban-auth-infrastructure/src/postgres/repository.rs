use async_trait::async_trait;
use chrono::{DateTime, Utc};
use maohuoban_auth_application::auth::AuthEventRecorder;
use maohuoban_auth_application::auth::{
    AuthAuditEvent, NewDeviceSession, PasswordCredential, SessionRepository, UserRepository,
};
use maohuoban_auth_domain::auth::{
    AccountDeviceSession, AuthError, AuthResult, AuthUser, RefreshSession, RefreshTokenResolution,
};
use sqlx::PgPool;
use uuid::Uuid;

mod event_recorder;
mod rows;
mod session;
mod user;

/// PostgresAuthRepository PostgreSQL 认证仓库
/// 核心职责：
/// - 持久化用户、手机号身份、密码凭证和设备 session
/// - 用数据库约束支撑登录唯一性和 refresh token 轮换
#[derive(Debug, Clone)]
pub struct PostgresAuthRepository {
    pool: PgPool,
}

impl PostgresAuthRepository {
    #[must_use]
    pub const fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    #[must_use]
    pub const fn pool(&self) -> &PgPool {
        &self.pool
    }
}

#[async_trait]
impl UserRepository for PostgresAuthRepository {
    async fn find_active_user_by_id(&self, user_id: Uuid) -> AuthResult<Option<AuthUser>> {
        self.find_active_user_by_id_query(user_id).await
    }

    async fn find_user_by_phone(&self, phone: &str) -> AuthResult<Option<AuthUser>> {
        self.find_user_by_phone_query(phone).await
    }

    async fn upsert_user_by_phone(&self, phone: &str) -> AuthResult<AuthUser> {
        self.upsert_user_by_phone_command(phone).await
    }

    async fn find_password_credential_by_phone(
        &self,
        phone: &str,
    ) -> AuthResult<Option<PasswordCredential>> {
        self.find_password_credential_by_phone_query(phone).await
    }

    async fn has_password_credential(&self, user_id: Uuid) -> AuthResult<bool> {
        self.has_password_credential_query(user_id).await
    }

    async fn save_password_credential(&self, user_id: Uuid, password_hash: &str) -> AuthResult<()> {
        self.save_password_credential_command(user_id, password_hash)
            .await
    }

    async fn update_last_login_at(&self, user_id: Uuid) -> AuthResult<()> {
        self.update_last_login_at_command(user_id).await
    }
}

#[async_trait]
impl SessionRepository for PostgresAuthRepository {
    async fn create_device_session(&self, session: NewDeviceSession) -> AuthResult<()> {
        self.create_device_session_command(session).await
    }

    async fn resolve_refresh_token(
        &self,
        refresh_token_hash: &str,
        device_id: &str,
    ) -> AuthResult<RefreshTokenResolution> {
        self.resolve_refresh_token_query(refresh_token_hash, device_id)
            .await
    }

    async fn find_active_session(
        &self,
        user_id: Uuid,
        session_id: Uuid,
    ) -> AuthResult<Option<RefreshSession>> {
        self.find_active_session_query(user_id, session_id).await
    }

    async fn rotate_refresh_token(
        &self,
        session_id: Uuid,
        old_refresh_token_hash: &str,
        new_refresh_token_hash: &str,
        expires_at: DateTime<Utc>,
    ) -> AuthResult<()> {
        self.rotate_refresh_token_command(
            session_id,
            old_refresh_token_hash,
            new_refresh_token_hash,
            expires_at,
        )
        .await
    }

    async fn revoke_session(&self, session_id: Uuid) -> AuthResult<()> {
        self.revoke_session_command(session_id).await
    }

    async fn list_active_device_sessions(
        &self,
        user_id: Uuid,
    ) -> AuthResult<Vec<AccountDeviceSession>> {
        self.list_active_device_sessions_query(user_id).await
    }

    async fn find_active_device_session(
        &self,
        user_id: Uuid,
        session_id: Uuid,
    ) -> AuthResult<Option<AccountDeviceSession>> {
        self.find_active_device_session_query(user_id, session_id)
            .await
    }

    async fn revoke_device_session(&self, user_id: Uuid, session_id: Uuid) -> AuthResult<bool> {
        self.revoke_device_session_command(user_id, session_id)
            .await
    }

    async fn revoke_user_sessions(&self, user_id: Uuid) -> AuthResult<()> {
        self.revoke_user_sessions_command(user_id).await
    }
}

#[async_trait]
impl AuthEventRecorder for PostgresAuthRepository {
    async fn record_auth_event(&self, event: AuthAuditEvent) -> AuthResult<()> {
        self.record_auth_event_command(event).await
    }
}

pub(super) fn to_infrastructure_error(error: sqlx::Error) -> AuthError {
    AuthError::Infrastructure(error.to_string())
}
