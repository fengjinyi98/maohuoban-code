mod password;
mod token;

pub use password::Argon2PasswordCredentialService;
pub use token::JwtTokenIssuer;

use std::fmt::Write as _;

use sha2::{Digest, Sha256};

/// sha256_hex SHA-256 十六进制摘要
/// 核心职责：
/// - 为验证码和 refresh token 提供稳定 hash
/// - 避免日志和数据库保存明文敏感 token
#[must_use]
pub fn sha256_hex(value: &str) -> String {
    let digest = Sha256::digest(value.as_bytes());
    let mut output = String::with_capacity(digest.len() * 2);
    for byte in digest {
        let _ = write!(&mut output, "{byte:02x}");
    }
    output
}
