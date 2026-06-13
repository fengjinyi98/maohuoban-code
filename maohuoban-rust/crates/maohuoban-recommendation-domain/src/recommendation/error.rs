use thiserror::Error;

pub type RecommendationResult<T> = Result<T, RecommendationError>;

/// RecommendationError 推荐领域错误
/// 核心职责：
/// - 表达首页和宠物世界推荐读取失败原因
/// - 隔离底层数据库或策略实现细节
#[derive(Debug, Error)]
pub enum RecommendationError {
    #[error("recommendation input is invalid: {0}")]
    InvalidInput(String),
    #[error("recommendation infrastructure error: {0}")]
    Infrastructure(String),
}
