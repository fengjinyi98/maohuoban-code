use thiserror::Error;

/// `LegalError` 法务文档领域错误
/// 核心职责：
/// - 表达文档不存在和基础设施异常
/// - 为 HTTP 层提供稳定错误映射
#[derive(Debug, Error)]
pub enum LegalError {
    #[error("legal document not found")]
    DocumentNotFound,
    #[error("infrastructure error: {0}")]
    Infrastructure(String),
}

pub type LegalResult<T> = Result<T, LegalError>;
