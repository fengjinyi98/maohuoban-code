use std::sync::Arc;

use axum::{
    extract::{FromRef, FromRequestParts},
    http::request::Parts,
};
use maohuoban_auth_application::auth::AuthService;
use maohuoban_auth_domain::auth::AuthenticatedSession;
use uuid::Uuid;

use super::{AuthRejection, authenticate_session_context};

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
    Arc<AuthService>: FromRef<S>,
{
    type Rejection = AuthRejection;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let auth = Arc::<AuthService>::from_ref(state);
        let session = authenticate_session_context(&auth, &parts.headers)
            .await
            .map_err(AuthRejection::from)?;
        Ok(Self { session })
    }
}
