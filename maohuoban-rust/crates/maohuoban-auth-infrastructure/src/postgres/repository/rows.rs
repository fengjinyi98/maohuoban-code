use maohuoban_auth_application::auth::PasswordCredential;
use maohuoban_auth_domain::auth::{AuthUser, RefreshSession};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow)]
pub(super) struct AuthUserRow {
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
pub(super) struct PasswordCredentialRow {
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
pub(super) struct RefreshSessionRow {
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
