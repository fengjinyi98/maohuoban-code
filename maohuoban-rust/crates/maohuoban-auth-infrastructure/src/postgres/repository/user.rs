use maohuoban_auth_application::auth::PasswordCredential;
use maohuoban_auth_domain::auth::{AuthResult, AuthUser};
use uuid::Uuid;

use super::PostgresAuthRepository;
use super::rows::{AuthUserRow, PasswordCredentialRow};
use super::to_infrastructure_error;

impl PostgresAuthRepository {
    pub(super) async fn find_active_user_by_id_query(
        &self,
        user_id: Uuid,
    ) -> AuthResult<Option<AuthUser>> {
        let user = sqlx::query_as::<_, AuthUserRow>(
            r#"
            SELECT u.id, ui.identifier AS phone
            FROM users u
            INNER JOIN user_identities ui ON ui.user_id = u.id
            WHERE u.id = $1
              AND u.status = 'active'
              AND ui.provider = 'phone'
            "#,
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?
        .map(Into::into);

        Ok(user)
    }

    pub(super) async fn find_user_by_phone_query(
        &self,
        phone: &str,
    ) -> AuthResult<Option<AuthUser>> {
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

    pub(super) async fn upsert_user_by_phone_command(&self, phone: &str) -> AuthResult<AuthUser> {
        if let Some(user) = self.find_user_by_phone_query(phone).await? {
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

    pub(super) async fn find_password_credential_by_phone_query(
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

    pub(super) async fn has_password_credential_query(&self, user_id: Uuid) -> AuthResult<bool> {
        let has_password = sqlx::query_scalar::<_, bool>(
            r#"
            SELECT EXISTS (
                SELECT 1
                FROM password_credentials
                WHERE user_id = $1
            )
            "#,
        )
        .bind(user_id)
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(has_password)
    }

    pub(super) async fn save_password_credential_command(
        &self,
        user_id: Uuid,
        password_hash: &str,
    ) -> AuthResult<()> {
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

    pub(super) async fn update_last_login_at_command(&self, user_id: Uuid) -> AuthResult<()> {
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
