use thiserror::Error;

pub type PetResult<T> = Result<T, PetError>;

/// PetError 宠物领域错误
/// 核心职责：
/// - 表达宠物档案和事件用例失败原因
/// - 为 HTTP 层提供稳定错误码映射依据
#[derive(Debug, Error)]
pub enum PetError {
    #[error("invalid pet input: {0}")]
    InvalidInput(String),
    #[error("pet name edit limit exceeded")]
    NameEditLimitExceeded,
    #[error("pet not found")]
    PetNotFound,
    #[error("pet album not found")]
    PetAlbumNotFound,
    #[error("pet album asset not found")]
    PetAlbumAssetNotFound,
    #[error("pet event not found")]
    PetEventNotFound,
    #[error("weight record not found")]
    WeightRecordNotFound,
    #[error("food inventory item not found")]
    FoodInventoryNotFound,
    #[error("diet assignment conflict: {0}")]
    DietAssignmentConflict(String),
    #[error("diet assignment not found")]
    DietAssignmentNotFound,
    #[error("pet access forbidden")]
    Forbidden,
    #[error("pet infrastructure error: {0}")]
    Infrastructure(String),
}
