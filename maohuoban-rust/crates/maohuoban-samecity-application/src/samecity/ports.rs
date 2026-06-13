use async_trait::async_trait;
use chrono::{DateTime, Utc};
use maohuoban_samecity_domain::samecity::{Hospital, HospitalAppointment, SameCityResult};
use uuid::Uuid;

/// BookHospitalAppointmentInput 医院预约输入
/// 核心职责：
/// - 汇总当前用户预约医院所需字段
/// - 保留宠物上下文和用户补充说明
#[derive(Debug, Clone)]
pub struct BookHospitalAppointmentInput {
    pub owner_user_id: Uuid,
    pub pet_id: Option<Uuid>,
    pub hospital_id: Uuid,
    pub scheduled_at: DateTime<Utc>,
    pub reason: String,
    pub note: Option<String>,
}

/// SameCityRepository 同城仓储端口
/// 核心职责：
/// - 查询同城可信医院实体
/// - 创建用户医院预约并校验宠物归属
#[async_trait]
pub trait SameCityRepository: Send + Sync {
    async fn list_verified_hospitals(&self, city: &str) -> SameCityResult<Vec<Hospital>>;

    async fn create_hospital_appointment(
        &self,
        input: BookHospitalAppointmentInput,
    ) -> SameCityResult<HospitalAppointment>;
}
