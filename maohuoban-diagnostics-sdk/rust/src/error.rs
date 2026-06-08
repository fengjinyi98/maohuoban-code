use thiserror::Error;

/// `DiagnosticsError` SDK 错误类型
/// 核心职责：
/// - 统一 IO 与 JSON 编解码错误
/// - 为调用方提供稳定错误边界
#[derive(Debug, Error)]
pub enum DiagnosticsError {
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("json error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("store lock poisoned")]
    StoreLockPoisoned,
}
