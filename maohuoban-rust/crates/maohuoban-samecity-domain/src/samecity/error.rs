use thiserror::Error;

pub type SameCityResult<T> = Result<T, SameCityError>;

/// SameCityError 同城领域错误
/// 核心职责：
/// - 表达同城实体与预约用例失败原因
/// - 为 HTTP 层提供稳定错误码映射依据
#[derive(Debug, Error)]
pub enum SameCityError {
    #[error("invalid samecity input: {0}")]
    InvalidInput(String),
    #[error("hospital not found")]
    HospitalNotFound,
    #[error("pet access forbidden")]
    PetForbidden,
    #[error("appointment not found")]
    AppointmentNotFound,
    #[error("appointment cannot be cancelled")]
    AppointmentNotCancellable,
    #[error("samecity infrastructure error: {0}")]
    Infrastructure(String),
}
