use std::sync::Arc;

use axum::{
    extract::{FromRef, FromRequestParts},
    http::request::Parts,
};
use maohuoban_auth_application::auth::AuthService;
use maohuoban_auth_domain::auth::AuthUser;
use uuid::Uuid;

use super::{AuthRejection, authenticate_user};

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
    Arc<AuthService>: FromRef<S>,
{
    type Rejection = AuthRejection;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let auth = Arc::<AuthService>::from_ref(state);
        let user = authenticate_user(&auth, &parts.headers)
            .await
            .map_err(AuthRejection::from)?;
        Ok(Self { user })
    }
}
