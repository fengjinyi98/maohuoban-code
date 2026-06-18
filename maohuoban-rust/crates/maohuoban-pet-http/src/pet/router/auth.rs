use axum::http::HeaderMap;
use maohuoban_auth_application::auth::AuthService;
use maohuoban_auth_domain::auth::{AuthError, AuthResult};
use uuid::Uuid;

pub(super) async fn current_user_id(auth: &AuthService, headers: &HeaderMap) -> AuthResult<Uuid> {
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
