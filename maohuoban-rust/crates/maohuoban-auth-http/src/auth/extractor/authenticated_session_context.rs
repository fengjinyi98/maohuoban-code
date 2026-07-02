use axum::{extract::FromRequestParts, http::request::Parts};
use maohuoban_auth_domain::auth::AuthenticatedSession;
use uuid::Uuid;

use super::AuthRejection;

/// AuthenticatedSessionContext 已鉴权会话提取器
/// 核心职责：
/// - 注入用户与当前 session 组合语义
/// - 支撑设备管理、登出、刷新等需要 session_id 的 HTTP 场景
#[derive(Debug, Clone)]
pub struct AuthenticatedSessionContext {
    pub session: AuthenticatedSession,
}

impl AuthenticatedSessionContext {
    #[must_use]
    pub const fn user_id(&self) -> Uuid {
        self.session.user.id
    }

    #[must_use]
    pub const fn session_id(&self) -> Uuid {
        self.session.session_id
    }
}

impl<S> FromRequestParts<S> for AuthenticatedSessionContext
where
    S: Send + Sync,
{
    type Rejection = AuthRejection;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let session = parts
            .extensions
            .get::<AuthenticatedSession>()
            .cloned()
            .ok_or_else(|| AuthRejection::missing_extension("authenticated_session"))?;
        Ok(Self { session })
    }
}
