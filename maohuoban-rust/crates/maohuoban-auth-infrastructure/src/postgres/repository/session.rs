use chrono::{DateTime, Utc};
use maohuoban_auth_application::auth::NewDeviceSession;
use maohuoban_auth_domain::auth::{
    AccountDeviceSession, AuthError, AuthResult, RefreshSession, RefreshTokenResolution,
};
use uuid::Uuid;

use super::PostgresAuthRepository;
use super::rows::{AccountDeviceSessionRow, RefreshSessionRow};
use super::to_infrastructure_error;

impl PostgresAuthRepository {
    pub(super) async fn create_device_session_command(
        &self,
        session: NewDeviceSession,
    ) -> AuthResult<()> {
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

    pub(super) async fn resolve_refresh_token_query(
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

    pub(super) async fn find_active_session_query(
        &self,
        user_id: Uuid,
        session_id: Uuid,
    ) -> AuthResult<Option<RefreshSession>> {
        let session = sqlx::query_as::<_, RefreshSessionRow>(
            r#"
            SELECT ds.id AS session_id,
                   u.id AS user_id,
                   ui.identifier AS phone,
                   ds.device_id
            FROM device_sessions ds
            INNER JOIN users u ON u.id = ds.user_id
            INNER JOIN user_identities ui ON ui.user_id = u.id AND ui.provider = 'phone'
            WHERE ds.id = $1
              AND ds.user_id = $2
              AND ds.revoked_at IS NULL
              AND ds.expires_at > now()
              AND u.status = 'active'
            "#,
        )
        .bind(session_id)
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?
        .map(Into::into);

        Ok(session)
    }

    pub(super) async fn rotate_refresh_token_command(
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

    pub(super) async fn revoke_session_command(&self, session_id: Uuid) -> AuthResult<()> {
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

    pub(super) async fn list_active_device_sessions_query(
        &self,
        user_id: Uuid,
    ) -> AuthResult<Vec<AccountDeviceSession>> {
        let rows = sqlx::query_as::<_, AccountDeviceSessionRow>(
            r#"
            SELECT id AS session_id,
                   user_id,
                   device_id,
                   device_name,
                   platform,
                   app_version,
                   created_at,
                   last_seen_at,
                   expires_at
            FROM device_sessions
            WHERE user_id = $1
              AND revoked_at IS NULL
              AND expires_at > now()
            ORDER BY last_seen_at DESC, created_at DESC
            "#,
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(rows.into_iter().map(Into::into).collect())
    }

    pub(super) async fn find_active_device_session_query(
        &self,
        user_id: Uuid,
        session_id: Uuid,
    ) -> AuthResult<Option<AccountDeviceSession>> {
        let row = sqlx::query_as::<_, AccountDeviceSessionRow>(
            r#"
            SELECT id AS session_id,
                   user_id,
                   device_id,
                   device_name,
                   platform,
                   app_version,
                   created_at,
                   last_seen_at,
                   expires_at
            FROM device_sessions
            WHERE id = $1
              AND user_id = $2
              AND revoked_at IS NULL
              AND expires_at > now()
            "#,
        )
        .bind(session_id)
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?
        .map(Into::into);

        Ok(row)
    }

    pub(super) async fn revoke_device_session_command(
        &self,
        user_id: Uuid,
        session_id: Uuid,
    ) -> AuthResult<bool> {
        let result = sqlx::query(
            r#"
            UPDATE device_sessions
            SET revoked_at = now(), updated_at = now()
            WHERE id = $1
              AND user_id = $2
              AND revoked_at IS NULL
              AND expires_at > now()
            "#,
        )
        .bind(session_id)
        .bind(user_id)
        .execute(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(result.rows_affected() == 1)
    }

    pub(super) async fn revoke_user_sessions_command(&self, user_id: Uuid) -> AuthResult<()> {
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
