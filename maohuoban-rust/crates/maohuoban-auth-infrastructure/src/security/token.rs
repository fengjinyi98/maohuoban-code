use chrono::{Duration, Utc};
use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation, decode, encode};
use maohuoban_auth_application::auth::TokenIssuer;
use maohuoban_auth_domain::auth::{AccessTokenSubject, AuthError, AuthResult, AuthUser};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::sha256_hex;

/// JwtTokenIssuer JWT 与 refresh token 服务
/// 核心职责：
/// - 签发短期 access token
/// - 生成 opaque refresh token 并提供 hash 能力
#[derive(Debug, Clone)]
pub struct JwtTokenIssuer {
    secret: String,
    access_token_ttl_seconds: i64,
    refresh_token_ttl_seconds: i64,
}

impl JwtTokenIssuer {
    #[must_use]
    pub fn new(
        secret: impl Into<String>,
        access_token_ttl_seconds: i64,
        refresh_token_ttl_seconds: i64,
    ) -> Self {
        Self {
            secret: secret.into(),
            access_token_ttl_seconds,
            refresh_token_ttl_seconds,
        }
    }
}

impl TokenIssuer for JwtTokenIssuer {
    fn issue_access_token(&self, user: &AuthUser, session_id: Uuid) -> AuthResult<String> {
        let issued_at = Utc::now();
        let expires_at = issued_at + Duration::seconds(self.access_token_ttl_seconds);
        let claims = AccessTokenClaims {
            sub: user.id.to_string(),
            phone: user.phone.clone(),
            session_id: session_id.to_string(),
            iat: issued_at.timestamp(),
            exp: expires_at.timestamp(),
        };
        encode(
            &Header::default(),
            &claims,
            &EncodingKey::from_secret(self.secret.as_bytes()),
        )
        .map_err(|error| AuthError::Token(error.to_string()))
    }

    fn verify_access_token(&self, access_token: &str) -> AuthResult<AccessTokenSubject> {
        let token = decode::<AccessTokenClaims>(
            access_token,
            &DecodingKey::from_secret(self.secret.as_bytes()),
            &Validation::default(),
        )
        .map_err(|_| AuthError::AccessInvalid)?;
        let user_id = Uuid::parse_str(&token.claims.sub).map_err(|_| AuthError::AccessInvalid)?;
        let session_id =
            Uuid::parse_str(&token.claims.session_id).map_err(|_| AuthError::AccessInvalid)?;

        Ok(AccessTokenSubject {
            user_id,
            session_id,
        })
    }

    fn generate_refresh_token(&self) -> AuthResult<String> {
        Ok(format!(
            "mhbr_{}_{}",
            Uuid::new_v4().simple(),
            Uuid::new_v4().simple()
        ))
    }

    fn hash_refresh_token(&self, refresh_token: &str) -> String {
        sha256_hex(refresh_token)
    }

    fn access_token_ttl_seconds(&self) -> i64 {
        self.access_token_ttl_seconds
    }

    fn refresh_token_ttl_seconds(&self) -> i64 {
        self.refresh_token_ttl_seconds
    }
}

/// AccessTokenClaims access token 载荷
/// 核心职责：
/// - 固定 JWT 中的用户、手机号、session 和时效字段
/// - 为后续业务接口鉴权提供最小身份上下文
#[derive(Debug, Clone, Serialize, Deserialize)]
struct AccessTokenClaims {
    sub: String,
    phone: String,
    session_id: String,
    iat: i64,
    exp: i64,
}
