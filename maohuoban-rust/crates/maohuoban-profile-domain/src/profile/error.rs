use thiserror::Error;

pub type ProfileResult<T> = Result<T, ProfileError>;

/// `ProfileError` 个人资料领域错误
/// 核心职责：
/// - 表达个人资料读取和写入失败原因
/// - 为 HTTP 层提供稳定错误映射依据
#[derive(Debug, Error)]
pub enum ProfileError {
    #[error("profile not found")]
    NotFound,
    #[error("display name invalid")]
    DisplayNameInvalid,
    #[error("display name edit limit exceeded")]
    DisplayNameEditLimitExceeded,
    #[error("bio invalid")]
    BioInvalid,
    #[error("bio edit limit exceeded")]
    BioEditLimitExceeded,
    #[error("gender invalid")]
    GenderInvalid,
    #[error("birthday invalid")]
    BirthdayInvalid,
    #[error("media file required")]
    MediaFileRequired,
    #[error("media type invalid")]
    MediaTypeInvalid,
    #[error("media too large")]
    MediaTooLarge,
    #[error("media decode failed")]
    MediaDecodeFailed,
    #[error("infrastructure error: {0}")]
    Infrastructure(String),
}
