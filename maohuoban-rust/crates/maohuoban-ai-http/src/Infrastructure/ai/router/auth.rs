//! auth AI HTTP 认证辅助
//! 核心职责：
//! - 从 Authorization header 提取 Bearer token 并鉴权
//! - 返回 actor_user_id，不信任请求体传入的 actor 字段

use axum::http::HeaderMap;
use maohuoban_auth_application::auth::AuthService;
use maohuoban_auth_domain::auth::{AuthError, AuthResult};
use uuid::Uuid;

/// current_user_id 从 header 提取并鉴权当前用户
pub async fn current_user_id(auth: &AuthService, headers: &HeaderMap) -> AuthResult<Uuid> {
    let token = bearer_token(headers)?;
    let user = auth.authenticate_access_token(token).await?;
    Ok(user.id)
}

fn bearer_token(headers: &HeaderMap) -> AuthResult<&str> {
    let value = headers
        .get("authorization")
        .ok_or(AuthError::AccessInvalid)?;
    let raw = value.to_str().map_err(|_| AuthError::AccessInvalid)?;
    raw.strip_prefix("Bearer ")
        .filter(|token| !token.is_empty())
        .ok_or(AuthError::AccessInvalid)
}
