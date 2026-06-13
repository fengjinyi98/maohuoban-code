use async_trait::async_trait;
use chrono::{DateTime, Utc};
use maohuoban_auth_application::auth::AuthEventRecorder;
use maohuoban_auth_application::auth::{
    AuthAuditEvent, NewDeviceSession, PasswordCredential, SessionRepository, UserRepository,
};
use maohuoban_auth_domain::auth::{
    AuthError, AuthResult, AuthUser, RefreshSession, RefreshTokenResolution,
};
use maohuoban_diagnostics::{DiagnosticEvent, Diagnostics, EventKind, Severity};
use serde_json::{Map, Value, json};
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

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
    async fn find_user_by_phone(&self, phone: &str) -> AuthResult<Option<AuthUser>> {
        let user = sqlx::query_as::<_, AuthUserRow>(
            r#"
            SELECT u.id, ui.identifier AS phone
            FROM users u
            INNER JOIN user_identities ui ON ui.user_id = u.id
            WHERE ui.provider = 'phone' AND ui.identifier = $1
            "#,
        )
        .bind(phone)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?
        .map(Into::into);

        Ok(user)
    }

    async fn upsert_user_by_phone(&self, phone: &str) -> AuthResult<AuthUser> {
        if let Some(user) = self.find_user_by_phone(phone).await? {
            return Ok(user);
        }

        let user_id = Uuid::new_v4();
        sqlx::query(
            r#"
            INSERT INTO users (id, status)
            VALUES ($1, 'active')
            ON CONFLICT (id) DO NOTHING
            "#,
        )
        .bind(user_id)
        .execute(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        let identity_user_id: Uuid = sqlx::query_scalar(
            r#"
            INSERT INTO user_identities (id, user_id, provider, identifier, verified_at)
            VALUES ($1, $2, 'phone', $3, now())
            ON CONFLICT (provider, identifier)
            DO UPDATE SET verified_at = COALESCE(user_identities.verified_at, EXCLUDED.verified_at)
            RETURNING user_id
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(user_id)
        .bind(phone)
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        let user = sqlx::query_as::<_, AuthUserRow>(
            r#"
            SELECT u.id, ui.identifier AS phone
            FROM users u
            INNER JOIN user_identities ui ON ui.user_id = u.id
            WHERE u.id = $1 AND ui.provider = 'phone'
            "#,
        )
        .bind(identity_user_id)
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(user.into())
    }

    async fn find_password_credential_by_phone(
        &self,
        phone: &str,
    ) -> AuthResult<Option<PasswordCredential>> {
        let credential = sqlx::query_as::<_, PasswordCredentialRow>(
            r#"
            SELECT u.id AS user_id, ui.identifier AS phone, pc.password_hash
            FROM users u
            INNER JOIN user_identities ui ON ui.user_id = u.id
            INNER JOIN password_credentials pc ON pc.user_id = u.id
            WHERE ui.provider = 'phone' AND ui.identifier = $1
            "#,
        )
        .bind(phone)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?
        .map(Into::into);

        Ok(credential)
    }

    async fn save_password_credential(&self, user_id: Uuid, password_hash: &str) -> AuthResult<()> {
        sqlx::query(
            r#"
            INSERT INTO password_credentials (user_id, password_hash, algorithm, updated_at)
            VALUES ($1, $2, 'argon2id', now())
            ON CONFLICT (user_id)
            DO UPDATE SET password_hash = EXCLUDED.password_hash,
                          algorithm = EXCLUDED.algorithm,
                          updated_at = now()
            "#,
        )
        .bind(user_id)
        .bind(password_hash)
        .execute(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;
        Ok(())
    }

    async fn update_last_login_at(&self, user_id: Uuid) -> AuthResult<()> {
        sqlx::query(
            r#"
            UPDATE users
            SET last_login_at = now(), updated_at = now()
            WHERE id = $1
            "#,
        )
        .bind(user_id)
        .execute(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;
        Ok(())
    }
}

#[async_trait]
impl SessionRepository for PostgresAuthRepository {
    async fn create_device_session(&self, session: NewDeviceSession) -> AuthResult<()> {
        sqlx::query(
            r#"
            INSERT INTO device_sessions (
                id,
                user_id,
                device_id,
                device_name,
                platform,
                app_version,
                refresh_token_hash,
                expires_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            "#,
        )
        .bind(session.session_id)
        .bind(session.user_id)
        .bind(session.device.device_id)
        .bind(session.device.device_name)
        .bind(session.device.platform)
        .bind(session.device.app_version)
        .bind(session.refresh_token_hash)
        .bind(session.expires_at)
        .execute(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;
        Ok(())
    }

    async fn resolve_refresh_token(
        &self,
        refresh_token_hash: &str,
        device_id: &str,
    ) -> AuthResult<RefreshTokenResolution> {
        if let Some(session) = self
            .find_session_by_refresh_hash(refresh_token_hash, device_id, RefreshHashColumn::Current)
            .await?
        {
            return Ok(RefreshTokenResolution::Active(session));
        }

        if let Some(session) = self
            .find_session_by_refresh_hash(
                refresh_token_hash,
                device_id,
                RefreshHashColumn::Previous,
            )
            .await?
        {
            return Ok(RefreshTokenResolution::Reused(session));
        }

        Ok(RefreshTokenResolution::Missing)
    }

    async fn rotate_refresh_token(
        &self,
        session_id: Uuid,
        old_refresh_token_hash: &str,
        new_refresh_token_hash: &str,
        expires_at: DateTime<Utc>,
    ) -> AuthResult<()> {
        let result = sqlx::query(
            r#"
            UPDATE device_sessions
            SET previous_refresh_token_hash = refresh_token_hash,
                refresh_token_hash = $1,
                expires_at = $2,
                updated_at = now(),
                last_seen_at = now()
            WHERE id = $3
              AND refresh_token_hash = $4
              AND revoked_at IS NULL
              AND expires_at > now()
            "#,
        )
        .bind(new_refresh_token_hash)
        .bind(expires_at)
        .bind(session_id)
        .bind(old_refresh_token_hash)
        .execute(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        if result.rows_affected() == 1 {
            Ok(())
        } else {
            Err(AuthError::RefreshInvalid)
        }
    }

    async fn revoke_session(&self, session_id: Uuid) -> AuthResult<()> {
        sqlx::query(
            r#"
            UPDATE device_sessions
            SET revoked_at = now(), updated_at = now()
            WHERE id = $1 AND revoked_at IS NULL
            "#,
        )
        .bind(session_id)
        .execute(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;
        Ok(())
    }

    async fn revoke_user_sessions(&self, user_id: Uuid) -> AuthResult<()> {
        sqlx::query(
            r#"
            UPDATE device_sessions
            SET revoked_at = now(), updated_at = now()
            WHERE user_id = $1 AND revoked_at IS NULL
            "#,
        )
        .bind(user_id)
        .execute(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;
        Ok(())
    }
}

#[async_trait]
impl AuthEventRecorder for PostgresAuthRepository {
    async fn record_auth_event(&self, event: AuthAuditEvent) -> AuthResult<()> {
        let metadata = event
            .metadata
            .iter()
            .map(|(key, value)| (key.clone(), Value::String(value.clone())))
            .collect::<Map<_, _>>();
        let metadata_value = Value::Object(metadata.clone());

        sqlx::query(
            r#"
            INSERT INTO auth_audit_events (id, user_id, event_type, metadata)
            VALUES ($1, $2, $3, $4)
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(event.user_id)
        .bind(&event.event_type)
        .bind(&metadata_value)
        .execute(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        if let Some(diagnostics) = Diagnostics::current() {
            let mut diagnostic_event =
                DiagnosticEvent::new(EventKind::Identity, Severity::Info, event.event_type);
            if let Some(user_id) = event.user_id {
                diagnostic_event = diagnostic_event.metadata("user_id", json!(user_id));
            }
            for (key, value) in metadata {
                diagnostic_event = diagnostic_event.metadata(key, value);
            }
            diagnostics.record(diagnostic_event);
        }

        Ok(())
    }
}

impl PostgresAuthRepository {
    async fn find_session_by_refresh_hash(
        &self,
        refresh_token_hash: &str,
        device_id: &str,
        column: RefreshHashColumn,
    ) -> AuthResult<Option<RefreshSession>> {
        let sql = match column {
            RefreshHashColumn::Current => {
                r#"
                SELECT ds.id AS session_id,
                       u.id AS user_id,
                       ui.identifier AS phone,
                       ds.device_id
                FROM device_sessions ds
                INNER JOIN users u ON u.id = ds.user_id
                INNER JOIN user_identities ui ON ui.user_id = u.id AND ui.provider = 'phone'
                WHERE ds.refresh_token_hash = $1
                  AND ds.device_id = $2
                  AND ds.revoked_at IS NULL
                  AND ds.expires_at > now()
                "#
            }
            RefreshHashColumn::Previous => {
                r#"
                SELECT ds.id AS session_id,
                       u.id AS user_id,
                       ui.identifier AS phone,
                       ds.device_id
                FROM device_sessions ds
                INNER JOIN users u ON u.id = ds.user_id
                INNER JOIN user_identities ui ON ui.user_id = u.id AND ui.provider = 'phone'
                WHERE ds.previous_refresh_token_hash = $1
                  AND ds.device_id = $2
                  AND ds.revoked_at IS NULL
                "#
            }
        };

        let session = sqlx::query_as::<_, RefreshSessionRow>(sql)
            .bind(refresh_token_hash)
            .bind(device_id)
            .fetch_optional(&self.pool)
            .await
            .map_err(to_infrastructure_error)?
            .map(Into::into);

        Ok(session)
    }
}

#[derive(Debug, Clone, Copy)]
enum RefreshHashColumn {
    Current,
    Previous,
}

#[derive(Debug, FromRow)]
struct AuthUserRow {
    id: Uuid,
    phone: String,
}

impl From<AuthUserRow> for AuthUser {
    fn from(row: AuthUserRow) -> Self {
        Self {
            id: row.id,
            phone: row.phone,
        }
    }
}

#[derive(Debug, FromRow)]
struct PasswordCredentialRow {
    user_id: Uuid,
    phone: String,
    password_hash: String,
}

impl From<PasswordCredentialRow> for PasswordCredential {
    fn from(row: PasswordCredentialRow) -> Self {
        Self {
            user: AuthUser {
                id: row.user_id,
                phone: row.phone,
            },
            password_hash: row.password_hash,
        }
    }
}

#[derive(Debug, FromRow)]
struct RefreshSessionRow {
    session_id: Uuid,
    user_id: Uuid,
    phone: String,
    device_id: String,
}

impl From<RefreshSessionRow> for RefreshSession {
    fn from(row: RefreshSessionRow) -> Self {
        Self {
            session_id: row.session_id,
            user: AuthUser {
                id: row.user_id,
                phone: row.phone,
            },
            device_id: row.device_id,
        }
    }
}

fn to_infrastructure_error(error: sqlx::Error) -> AuthError {
    AuthError::Infrastructure(error.to_string())
}
