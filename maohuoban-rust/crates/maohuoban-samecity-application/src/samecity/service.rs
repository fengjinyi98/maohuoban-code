use std::sync::Arc;

use maohuoban_samecity_domain::samecity::{
    Hospital, HospitalAppointment, SameCityError, SameCityResult,
};
use uuid::Uuid;

use super::{BookHospitalAppointmentInput, SameCityRepository};

/// SameCityService 同城应用服务
/// 核心职责：
/// - 承接同城医院查询和预约用例
/// - 将输入校验与仓储实现隔离
pub struct SameCityService {
    repository: Arc<dyn SameCityRepository>,
}

impl SameCityService {
    #[must_use]
    pub fn new(repository: Arc<dyn SameCityRepository>) -> Self {
        Self { repository }
    }

    pub async fn list_bookable_partner_hospitals(
        &self,
        city: &str,
    ) -> SameCityResult<Vec<Hospital>> {
        validate_text("城市", city)?;
        self.repository
            .list_bookable_partner_hospitals(city.trim())
            .await
    }

    pub async fn create_hospital_appointment(
        &self,
        input: BookHospitalAppointmentInput,
    ) -> SameCityResult<HospitalAppointment> {
        validate_uuid("医院", input.hospital_id)?;
        validate_text("预约原因", &input.reason)?;
        self.repository.create_hospital_appointment(input).await
    }

    pub async fn cancel_hospital_appointment(
        &self,
        owner_user_id: Uuid,
        appointment_id: Uuid,
    ) -> SameCityResult<HospitalAppointment> {
        validate_uuid("预约", appointment_id)?;
        self.repository
            .cancel_hospital_appointment(owner_user_id, appointment_id)
            .await
    }
}

fn validate_text(field: &str, value: &str) -> SameCityResult<()> {
    if value.trim().is_empty() {
        return Err(SameCityError::InvalidInput(format!("{field}不能为空")));
    }
    Ok(())
}

fn validate_uuid(field: &str, value: Uuid) -> SameCityResult<()> {
    if value.is_nil() {
        return Err(SameCityError::InvalidInput(format!("{field}不能为空")));
    }
    Ok(())
}
