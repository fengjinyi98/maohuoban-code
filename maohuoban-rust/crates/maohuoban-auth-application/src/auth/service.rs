use std::{collections::BTreeMap, sync::Arc};

use chrono::{Duration, Utc};
use maohuoban_auth_domain::auth::{
    AuthError, AuthResult, AuthSession, DeviceDescriptor, OAuthProvider, PhoneCodeChallenge,
    RefreshTokenResolution, TokenPair,
};
use uuid::Uuid;

use super::{
    AuthAuditEvent, AuthEventRecorder, NewDeviceSession, OtpChallengeStore,
    PasswordCredentialService, SessionRepository, TokenIssuer, UserRepository,
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

    pub async fn send_phone_code(
        &self,
        phone: &str,
        agreement_accepted: bool,
    ) -> AuthResult<PhoneCodeChallenge> {
        let phone = normalize_phone(phone)?;
        if !agreement_accepted {
            return Err(AuthError::AgreementRequired);
        }

        let challenge = self
            .otp_store
            .create_login_challenge(
                "login",
                &phone,
                &self.config.development_fixed_code,
                self.config.otp_ttl_seconds,
                self.config.otp_resend_cooldown_seconds,
            )
            .await?;
        self.record_event(
            None,
            "auth.phone_code.sent",
            [("phone", mask_phone(&phone))],
        )
        .await;
        Ok(challenge)
    }

    pub async fn send_account_recovery_code(&self, phone: &str) -> AuthResult<PhoneCodeChallenge> {
        let phone = normalize_phone(phone)?;
        if self.users.find_user_by_phone(&phone).await?.is_none() {
            return Err(AuthError::UserNotFound);
        }

        let challenge = self
            .otp_store
            .create_login_challenge(
                "recovery",
                &phone,
                &self.config.development_fixed_code,
                self.config.otp_ttl_seconds,
                self.config.otp_resend_cooldown_seconds,
            )
            .await?;
        self.record_event(
            None,
            "account_recovery.code.sent",
            [("phone", mask_phone(&phone))],
        )
        .await;
        Ok(challenge)
    }

    pub async fn verify_phone_code(
        &self,
        challenge_id: &str,
        code: &str,
        device: DeviceDescriptor,
    ) -> AuthResult<AuthSession> {
        let phone = self
            .otp_store
            .verify_login_challenge(challenge_id, code)
            .await?;
        let user = self.users.upsert_user_by_phone(&phone).await?;
        self.users.update_last_login_at(user.id).await?;
        let session = self.create_login_session(user, device).await?;
        self.record_event(
            Some(session.user.id),
            "auth.phone_code.login_success",
            [("phone", mask_phone(&session.user.phone))],
        )
        .await;
        Ok(session)
    }

    pub async fn password_login(
        &self,
        phone: &str,
        password: &str,
        device: DeviceDescriptor,
    ) -> AuthResult<AuthSession> {
        let phone = normalize_phone(phone)?;
        let credential = self
            .users
            .find_password_credential_by_phone(&phone)
            .await?
            .ok_or(AuthError::InvalidCredentials)?;

        let is_valid = self
            .passwords
            .verify_password(password, &credential.password_hash)?;
        if !is_valid {
            self.record_event(
                Some(credential.user.id),
                "auth.password.login_failed",
                [("phone", mask_phone(&phone))],
            )
            .await;
            return Err(AuthError::InvalidCredentials);
        }

        self.users.update_last_login_at(credential.user.id).await?;
        let session = self.create_login_session(credential.user, device).await?;
        self.record_event(
            Some(session.user.id),
            "auth.password.login_success",
            [("phone", mask_phone(&session.user.phone))],
        )
        .await;
        Ok(session)
    }

    pub async fn refresh(&self, refresh_token: &str, device_id: &str) -> AuthResult<AuthSession> {
        let refresh_token_hash = self.tokens.hash_refresh_token(refresh_token);
        match self
            .sessions
            .resolve_refresh_token(&refresh_token_hash, device_id)
            .await?
        {
            RefreshTokenResolution::Active(session) => {
                let new_refresh_token = self.tokens.generate_refresh_token()?;
                let new_refresh_token_hash = self.tokens.hash_refresh_token(&new_refresh_token);
                let refresh_expires_at =
                    Utc::now() + Duration::seconds(self.tokens.refresh_token_ttl_seconds());
                self.sessions
                    .rotate_refresh_token(
                        session.session_id,
                        &refresh_token_hash,
                        &new_refresh_token_hash,
                        refresh_expires_at,
                    )
                    .await?;
                let access_token = self
                    .tokens
                    .issue_access_token(&session.user, session.session_id)?;
                let auth_session = AuthSession {
                    user: session.user,
                    tokens: TokenPair {
                        access_token,
                        refresh_token: new_refresh_token,
                        token_type: "Bearer".to_owned(),
                        expires_in_seconds: self.tokens.access_token_ttl_seconds(),
                        refresh_expires_in_seconds: self.tokens.refresh_token_ttl_seconds(),
                    },
                };
                self.record_event(
                    Some(auth_session.user.id),
                    "auth.refresh.rotated",
                    [("device_id", session.device_id)],
                )
                .await;
                Ok(auth_session)
            }
            RefreshTokenResolution::Reused(session) => {
                self.sessions.revoke_session(session.session_id).await?;
                self.record_event(
                    Some(session.user.id),
                    "auth.refresh.reused",
                    [("device_id", session.device_id)],
                )
                .await;
                Err(AuthError::RefreshReused)
            }
            RefreshTokenResolution::Missing => Err(AuthError::RefreshInvalid),
        }
    }

    pub async fn logout(&self, refresh_token: &str, device_id: &str) -> AuthResult<()> {
        let refresh_token_hash = self.tokens.hash_refresh_token(refresh_token);
        match self
            .sessions
            .resolve_refresh_token(&refresh_token_hash, device_id)
            .await?
        {
            RefreshTokenResolution::Active(session) | RefreshTokenResolution::Reused(session) => {
                self.sessions.revoke_session(session.session_id).await?;
                self.record_event(
                    Some(session.user.id),
                    "auth.logout.success",
                    [("device_id", session.device_id)],
                )
                .await;
                Ok(())
            }
            RefreshTokenResolution::Missing => Err(AuthError::RefreshInvalid),
        }
    }

    pub async fn reset_password(
        &self,
        challenge_id: &str,
        code: &str,
        new_password: &str,
    ) -> AuthResult<()> {
        let phone = self
            .otp_store
            .verify_login_challenge(challenge_id, code)
            .await?;
        let user = self
            .users
            .find_user_by_phone(&phone)
            .await?
            .ok_or(AuthError::UserNotFound)?;
        let password_hash = self.passwords.hash_password(new_password)?;
        self.users
            .save_password_credential(user.id, &password_hash)
            .await?;
        self.sessions.revoke_user_sessions(user.id).await?;
        self.record_event(
            Some(user.id),
            "account_recovery.password_reset",
            [("phone", mask_phone(&phone))],
        )
        .await;
        Ok(())
    }

    pub fn oauth_login(&self, provider: OAuthProvider) -> AuthResult<AuthSession> {
        Err(AuthError::OAuthTodo(provider))
    }

    async fn create_login_session(
        &self,
        user: maohuoban_auth_domain::auth::AuthUser,
        device: DeviceDescriptor,
    ) -> AuthResult<AuthSession> {
        let session_id = Uuid::new_v4();
        let refresh_token = self.tokens.generate_refresh_token()?;
        let refresh_token_hash = self.tokens.hash_refresh_token(&refresh_token);
        let refresh_expires_at =
            Utc::now() + Duration::seconds(self.tokens.refresh_token_ttl_seconds());
        self.sessions
            .create_device_session(NewDeviceSession {
                session_id,
                user_id: user.id,
                device,
                refresh_token_hash,
                expires_at: refresh_expires_at,
            })
            .await?;
        let access_token = self.tokens.issue_access_token(&user, session_id)?;
        Ok(AuthSession {
            user,
            tokens: TokenPair {
                access_token,
                refresh_token,
                token_type: "Bearer".to_owned(),
                expires_in_seconds: self.tokens.access_token_ttl_seconds(),
                refresh_expires_in_seconds: self.tokens.refresh_token_ttl_seconds(),
            },
        })
    }

    async fn record_event(
        &self,
        user_id: Option<Uuid>,
        event_type: &str,
        metadata: impl IntoIterator<Item = (&'static str, String)>,
    ) {
        let metadata = metadata
            .into_iter()
            .map(|(key, value)| (key.to_owned(), value))
            .collect::<BTreeMap<_, _>>();
        let _ = self
            .events
            .record_auth_event(AuthAuditEvent {
                user_id,
                event_type: event_type.to_owned(),
                metadata,
            })
            .await;
    }
}

fn normalize_phone(phone: &str) -> AuthResult<String> {
    let phone = phone.trim();
    let is_valid = phone.len() == 11 && phone.chars().all(|item| item.is_ascii_digit());
    if is_valid {
        Ok(phone.to_owned())
    } else {
        Err(AuthError::InvalidPhone)
    }
}

fn mask_phone(phone: &str) -> String {
    if phone.len() == 11 {
        format!("{}****{}", &phone[0..3], &phone[7..11])
    } else {
        "<invalid-phone>".to_owned()
    }
}
