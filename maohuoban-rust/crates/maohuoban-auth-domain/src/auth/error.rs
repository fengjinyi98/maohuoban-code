use thiserror::Error;

use super::OAuthProvider;

pub type AuthResult<T> = Result<T, AuthError>;

/// AuthError 认证领域错误
/// 核心职责：
/// - 表达登录、验证码、会话刷新中的业务失败原因
/// - 为接口层提供稳定错误码映射依据
#[derive(Debug, Error)]
pub enum AuthError {
    #[error("invalid phone")]
    InvalidPhone,
    #[error("agreement required")]
    AgreementRequired,
    #[error("invalid code")]
    InvalidCode,
    #[error("challenge expired")]
    ChallengeExpired,
    #[error("code send cooling down: {retry_after_seconds}s")]
    CodeCoolingDown { retry_after_seconds: i64 },
    #[error("too many attempts")]
    TooManyAttempts,
    #[error("invalid credentials")]
    InvalidCredentials,
    #[error("user not found")]
    UserNotFound,
    #[error("refresh token invalid")]
    RefreshInvalid,
    #[error("refresh token reused")]
    RefreshReused,
    #[error("{0} oauth todo")]
    OAuthTodo(OAuthProvider),
    #[error("password error: {0}")]
    Password(String),
    #[error("token error: {0}")]
    Token(String),
    #[error("infrastructure error: {0}")]
    Infrastructure(String),
}
