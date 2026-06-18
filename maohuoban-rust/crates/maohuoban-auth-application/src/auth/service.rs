use std::sync::Arc;

mod events;
mod password;
mod phone;
mod session;

use super::{
    AuthEventRecorder, OtpChallengeStore, PasswordCredentialService, SessionRepository,
    TokenIssuer, UserRepository,
};

/// AuthServiceConfig 认证用例配置
/// 核心职责：
/// - 固定开发环境验证码和验证码 TTL
/// - 让 token 时效由 token 端口统一控制
#[derive(Debug, Clone)]
pub struct AuthServiceConfig {
    pub development_fixed_code: String,
    pub otp_ttl_seconds: i64,
    pub otp_resend_cooldown_seconds: i64,
}

impl Default for AuthServiceConfig {
    fn default() -> Self {
        Self {
            development_fixed_code: "123456".to_owned(),
            otp_ttl_seconds: 300,
            otp_resend_cooldown_seconds: 60,
        }
    }
}

/// AuthService 认证应用服务
/// 核心职责：
/// - 编排验证码登录、密码登录和 refresh 轮换
/// - 通过端口隔离 Redis、PostgreSQL、JWT、Argon2 等基础设施
#[derive(Clone)]
pub struct AuthService {
    config: AuthServiceConfig,
    otp_store: Arc<dyn OtpChallengeStore>,
    users: Arc<dyn UserRepository>,
    passwords: Arc<dyn PasswordCredentialService>,
    sessions: Arc<dyn SessionRepository>,
    tokens: Arc<dyn TokenIssuer>,
    events: Arc<dyn AuthEventRecorder>,
}

impl AuthService {
    #[must_use]
    pub fn new(
        config: AuthServiceConfig,
        otp_store: Arc<dyn OtpChallengeStore>,
        users: Arc<dyn UserRepository>,
        passwords: Arc<dyn PasswordCredentialService>,
        sessions: Arc<dyn SessionRepository>,
        tokens: Arc<dyn TokenIssuer>,
        events: Arc<dyn AuthEventRecorder>,
    ) -> Self {
        Self {
            config,
            otp_store,
            users,
            passwords,
            sessions,
            tokens,
            events,
        }
    }
}
