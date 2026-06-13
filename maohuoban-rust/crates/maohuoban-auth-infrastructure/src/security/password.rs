use argon2::{
    Argon2, PasswordHash, PasswordHasher, PasswordVerifier,
    password_hash::{SaltString, rand_core::OsRng},
};
use maohuoban_auth_application::auth::PasswordCredentialService;
use maohuoban_auth_domain::auth::{AuthError, AuthResult};

/// Argon2PasswordCredentialService Argon2 密码服务
/// 核心职责：
/// - 使用 Argon2id 生成密码 hash
/// - 校验登录明文密码
#[derive(Debug, Clone, Default)]
pub struct Argon2PasswordCredentialService;

impl PasswordCredentialService for Argon2PasswordCredentialService {
    fn hash_password(&self, password: &str) -> AuthResult<String> {
        let salt = SaltString::generate(&mut OsRng);
        Argon2::default()
            .hash_password(password.as_bytes(), &salt)
            .map(|hash| hash.to_string())
            .map_err(|error| AuthError::Password(error.to_string()))
    }

    fn verify_password(&self, password: &str, password_hash: &str) -> AuthResult<bool> {
        let parsed = PasswordHash::new(password_hash)
            .map_err(|error| AuthError::Password(error.to_string()))?;
        Ok(Argon2::default()
            .verify_password(password.as_bytes(), &parsed)
            .is_ok())
    }
}
