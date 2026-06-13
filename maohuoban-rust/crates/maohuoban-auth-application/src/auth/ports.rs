use std::collections::BTreeMap;

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use maohuoban_auth_domain::auth::{
    AuthResult, AuthUser, DeviceDescriptor, PhoneCodeChallenge, RefreshTokenResolution,
};
use uuid::Uuid;

/// PasswordCredential 密码凭证读模型
/// 核心职责：
/// - 承载密码登录需要的密码 hash
/// - 避免应用层接触数据库行结构
#[derive(Debug, Clone)]
pub struct PasswordCredential {
    pub user: AuthUser,
    pub password_hash: String,
}

/// NewDeviceSession 新建设备会话输入
/// 核心职责：
/// - 汇总创建 refresh session 所需字段
/// - 保持应用层和持久化层的写入契约稳定
#[derive(Debug, Clone)]
pub struct NewDeviceSession {
    pub session_id: Uuid,
    pub user_id: Uuid,
    pub device: DeviceDescriptor,
    pub refresh_token_hash: String,
    pub expires_at: DateTime<Utc>,
}

/// AuthAuditEvent 认证观测事件
/// 核心职责：
/// - 表达认证链路中需要持久化和诊断采集的业务事件
/// - 避免应用层依赖具体观测 SDK 或数据库结构
#[derive(Debug, Clone)]
pub struct AuthAuditEvent {
    pub user_id: Option<Uuid>,
    pub event_type: String,
    pub metadata: BTreeMap<String, String>,
}

/// OtpChallengeStore 验证码挑战端口
/// 核心职责：
/// - 创建短期验证码挑战
/// - 完成一次性验证码校验并返回手机号
#[async_trait]
pub trait OtpChallengeStore: Send + Sync {
    async fn create_login_challenge(
        &self,
        phone: &str,
        code: &str,
        ttl_seconds: i64,
    ) -> AuthResult<PhoneCodeChallenge>;

    async fn verify_login_challenge(&self, challenge_id: &str, code: &str) -> AuthResult<String>;
}

/// UserRepository 用户身份端口
/// 核心职责：
/// - 通过手机号查找或创建用户
/// - 读取和保存密码凭证
#[async_trait]
pub trait UserRepository: Send + Sync {
    async fn find_user_by_phone(&self, phone: &str) -> AuthResult<Option<AuthUser>>;

    async fn upsert_user_by_phone(&self, phone: &str) -> AuthResult<AuthUser>;

    async fn find_password_credential_by_phone(
        &self,
        phone: &str,
    ) -> AuthResult<Option<PasswordCredential>>;

    async fn save_password_credential(&self, user_id: Uuid, password_hash: &str) -> AuthResult<()>;

    async fn update_last_login_at(&self, user_id: Uuid) -> AuthResult<()>;
}

/// PasswordCredentialService 密码安全端口
/// 核心职责：
/// - 生成密码 hash
/// - 校验明文密码与 hash 是否匹配
pub trait PasswordCredentialService: Send + Sync {
    fn hash_password(&self, password: &str) -> AuthResult<String>;

    fn verify_password(&self, password: &str, password_hash: &str) -> AuthResult<bool>;
}

/// SessionRepository 设备会话端口
/// 核心职责：
/// - 创建和轮换 refresh token 会话
/// - 支持旧 refresh token 重放识别和撤销
#[async_trait]
pub trait SessionRepository: Send + Sync {
    async fn create_device_session(&self, session: NewDeviceSession) -> AuthResult<()>;

    async fn resolve_refresh_token(
        &self,
        refresh_token_hash: &str,
        device_id: &str,
    ) -> AuthResult<RefreshTokenResolution>;

    async fn rotate_refresh_token(
        &self,
        session_id: Uuid,
        old_refresh_token_hash: &str,
        new_refresh_token_hash: &str,
        expires_at: DateTime<Utc>,
    ) -> AuthResult<()>;

    async fn revoke_session(&self, session_id: Uuid) -> AuthResult<()>;

    async fn revoke_user_sessions(&self, user_id: Uuid) -> AuthResult<()>;
}

/// TokenIssuer token 签发端口
/// 核心职责：
/// - 签发 access token
/// - 生成和 hash refresh token
pub trait TokenIssuer: Send + Sync {
    fn issue_access_token(&self, user: &AuthUser, session_id: Uuid) -> AuthResult<String>;

    fn generate_refresh_token(&self) -> AuthResult<String>;

    fn hash_refresh_token(&self, refresh_token: &str) -> String;

    fn access_token_ttl_seconds(&self) -> i64;

    fn refresh_token_ttl_seconds(&self) -> i64;
}

/// AuthEventRecorder 认证观测端口
/// 核心职责：
/// - 写入认证审计事件
/// - 将应用层事件交给基础设施层同步到诊断系统
#[async_trait]
pub trait AuthEventRecorder: Send + Sync {
    async fn record_auth_event(&self, event: AuthAuditEvent) -> AuthResult<()>;
}
