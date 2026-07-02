use axum::{extract::FromRequestParts, http::request::Parts};
use maohuoban_auth_domain::auth::AuthUser;
use uuid::Uuid;

use super::AuthRejection;

/// AuthenticatedUser 已鉴权用户提取器
/// 核心职责：
/// - 统一从 request parts 注入当前已鉴权用户
/// - 避免各 HTTP crate 重复编写 HeaderMap -> user 鉴权样板
#[derive(Debug, Clone)]
pub struct AuthenticatedUser {
    pub user: AuthUser,
}

impl AuthenticatedUser {
    #[must_use]
    pub const fn user_id(&self) -> Uuid {
        self.user.id
    }
}

impl<S> FromRequestParts<S> for AuthenticatedUser
where
    S: Send + Sync,
{
    type Rejection = AuthRejection;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let user = parts
            .extensions
            .get::<AuthUser>()
            .cloned()
            .ok_or_else(|| AuthRejection::missing_extension("authenticated_user"))?;
        Ok(Self { user })
    }
}
