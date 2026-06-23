use std::sync::Arc;

mod devices;
mod events;
mod password;
mod phone;
mod session;

use super::{
    AuthEventRecorder, OtpChallengeStore, PasswordCredentialService, SessionRepository,
    TokenIssuer, UserProfileInitializer, UserRepository,
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
    profiles: Arc<dyn UserProfileInitializer>,
}

/// `AuthServiceDependencies` 认证服务依赖集合
/// 核心职责：
/// - 聚合认证用例所需的基础设施端口
/// - 避免服务构造函数随业务端口增长而失控
pub struct AuthServiceDependencies {
    pub otp_store: Arc<dyn OtpChallengeStore>,
    pub users: Arc<dyn UserRepository>,
    pub passwords: Arc<dyn PasswordCredentialService>,
    pub sessions: Arc<dyn SessionRepository>,
    pub tokens: Arc<dyn TokenIssuer>,
    pub events: Arc<dyn AuthEventRecorder>,
    pub profiles: Arc<dyn UserProfileInitializer>,
}

impl AuthService {
    #[must_use]
    pub fn new(config: AuthServiceConfig, dependencies: AuthServiceDependencies) -> Self {
        Self {
            config,
            otp_store: dependencies.otp_store,
            users: dependencies.users,
            passwords: dependencies.passwords,
            sessions: dependencies.sessions,
            tokens: dependencies.tokens,
            events: dependencies.events,
            profiles: dependencies.profiles,
        }
    }
}
