use async_trait::async_trait;
use maohuoban_auth_application::auth::OtpChallengeStore;
use maohuoban_auth_domain::auth::{AuthError, AuthResult, PhoneCodeChallenge};
use redis::{AsyncCommands, aio::ConnectionManager};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::security::sha256_hex;

/// RedisOtpChallengeStore Redis 验证码挑战仓库
/// 核心职责：
/// - 保存短期手机号验证码 challenge
/// - 完成一次性消费和验证码 hash 比对
#[derive(Clone)]
pub struct RedisOtpChallengeStore {
    connection: ConnectionManager,
    key_prefix: String,
}

impl RedisOtpChallengeStore {
    #[must_use]
    pub fn new(connection: ConnectionManager, key_prefix: impl Into<String>) -> Self {
        Self {
            connection,
            key_prefix: key_prefix.into(),
        }
    }

    fn otp_key(&self, challenge_id: &str) -> String {
        format!("{}:otp:{challenge_id}", self.key_prefix)
    }

    fn cooldown_key(&self, purpose: &str, phone: &str) -> String {
        format!(
            "{}:otp:cooldown:{purpose}:{}",
            self.key_prefix,
            sha256_hex(phone)
        )
    }
}

#[async_trait]
impl OtpChallengeStore for RedisOtpChallengeStore {
    async fn create_login_challenge(
        &self,
        purpose: &str,
        phone: &str,
        code: &str,
        ttl_seconds: i64,
        resend_cooldown_seconds: i64,
    ) -> AuthResult<PhoneCodeChallenge> {
        let challenge_id = Uuid::new_v4().to_string();
        let key = self.otp_key(&challenge_id);
        let cooldown_key = self.cooldown_key(purpose, phone);
        let cooldown_ttl = u64::try_from(resend_cooldown_seconds)
            .map_err(|error| AuthError::Infrastructure(error.to_string()))?;
        let mut connection = self.connection.clone();
        let cooldown_result: Option<String> = redis::cmd("SET")
            .arg(&cooldown_key)
            .arg("1")
            .arg("EX")
            .arg(cooldown_ttl)
            .arg("NX")
            .query_async(&mut connection)
            .await
            .map_err(|error| AuthError::Infrastructure(error.to_string()))?;
        if cooldown_result.is_none() {
            let retry_after_seconds: i64 = connection
                .ttl(&cooldown_key)
                .await
                .map_err(|error| AuthError::Infrastructure(error.to_string()))?;
            return Err(AuthError::CodeCoolingDown {
                retry_after_seconds: retry_after_seconds.max(1),
            });
        }

        let stored = StoredOtpChallenge {
            phone: phone.to_owned(),
            code_hash: sha256_hex(code),
        };
        let payload = serde_json::to_string(&stored)
            .map_err(|error| AuthError::Infrastructure(error.to_string()))?;
        let ttl = u64::try_from(ttl_seconds)
            .map_err(|error| AuthError::Infrastructure(error.to_string()))?;
        let _: () = connection
            .set_ex(key, payload, ttl)
            .await
            .map_err(|error| AuthError::Infrastructure(error.to_string()))?;
        Ok(PhoneCodeChallenge {
            challenge_id,
            expires_in_seconds: ttl_seconds,
            resend_after_seconds: resend_cooldown_seconds,
        })
    }

    async fn verify_login_challenge(&self, challenge_id: &str, code: &str) -> AuthResult<String> {
        let key = self.otp_key(challenge_id);
        let mut connection = self.connection.clone();
        let payload: Option<String> = connection
            .get(&key)
            .await
            .map_err(|error| AuthError::Infrastructure(error.to_string()))?;
        let payload = payload.ok_or(AuthError::ChallengeExpired)?;
        let stored: StoredOtpChallenge = serde_json::from_str(&payload)
            .map_err(|error| AuthError::Infrastructure(error.to_string()))?;
        if stored.code_hash != sha256_hex(code) {
            return Err(AuthError::InvalidCode);
        }
        let _: () = connection
            .del(key)
            .await
            .map_err(|error| AuthError::Infrastructure(error.to_string()))?;
        Ok(stored.phone)
    }
}

/// StoredOtpChallenge Redis 验证码载荷
/// 核心职责：
/// - 保存手机号和验证码 hash
/// - 避免 Redis 中出现明文验证码
#[derive(Debug, Serialize, Deserialize)]
struct StoredOtpChallenge {
    phone: String,
    code_hash: String,
}
