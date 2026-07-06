use chrono::{DateTime, Utc};
use maohuoban_samecity_application::samecity::BookHospitalAppointmentInput;
use maohuoban_samecity_domain::samecity::{Hospital, HospitalAppointment};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// HospitalsQuery 医院列表查询参数
/// 核心职责：
/// - 接收城市筛选条件
/// - 为后续服务类型和排序扩展保留查询结构
#[derive(Debug, Deserialize)]
pub(super) struct HospitalsQuery {
    pub city: String,
}

/// BookHospitalAppointmentRequest 医院预约请求
/// 核心职责：
/// - 接收用户从首页或同城页提交的预约字段
/// - 转换为应用层预约命令
#[derive(Debug, Deserialize)]
pub(super) struct BookHospitalAppointmentRequest {
    hospital_id: Uuid,
    pet_id: Option<Uuid>,
    scheduled_at: DateTime<Utc>,
    reason: String,
    note: Option<String>,
}

impl BookHospitalAppointmentRequest {
    pub(super) fn into_input(self, owner_user_id: Uuid) -> BookHospitalAppointmentInput {
        BookHospitalAppointmentInput {
            owner_user_id,
            pet_id: self.pet_id,
            hospital_id: self.hospital_id,
            scheduled_at: self.scheduled_at,
            reason: self.reason,
            note: self.note,
        }
    }
}

/// HospitalsData 医院列表响应数据
/// 核心职责：
/// - 返回城市和医院列表
/// - 保持同城页与首页选择医院共用契约
#[derive(Debug, Serialize)]
pub(super) struct HospitalsData {
    city: String,
    hospitals: Vec<HospitalData>,
}

impl HospitalsData {
    pub(super) fn new(city: String, hospitals: Vec<Hospital>) -> Self {
        Self {
            city,
            hospitals: hospitals.into_iter().map(HospitalData::from).collect(),
        }
    }
}

/// HospitalData 医院响应数据
/// 核心职责：
/// - 输出同城医院基础展示字段
/// - 隔离领域模型和 HTTP 字段命名
#[derive(Debug, Serialize)]
struct HospitalData {
    id: Uuid,
    name: String,
    city: String,
    district: Option<String>,
    address: String,
    phone: Option<String>,
    service_tags: Vec<String>,
    verification_status: String,
    partnership_status: String,
    his_enabled: bool,
    his_tenant_id: Option<Uuid>,
    appointment_enabled: bool,
    medical_record_return_enabled: bool,
}

impl From<Hospital> for HospitalData {
    fn from(hospital: Hospital) -> Self {
        Self {
            id: hospital.id,
            name: hospital.name,
            city: hospital.city,
            district: hospital.district,
            address: hospital.address,
            phone: hospital.phone,
            service_tags: hospital.service_tags,
            verification_status: hospital.verification_status.as_str().to_owned(),
            partnership_status: hospital.partnership_status.as_str().to_owned(),
            his_enabled: hospital.his_enabled,
            his_tenant_id: hospital.his_tenant_id,
            appointment_enabled: hospital.appointment_enabled,
            medical_record_return_enabled: hospital.medical_record_return_enabled,
        }
    }
}

/// HospitalAppointmentData 医院预约响应数据
/// 核心职责：
/// - 返回预约创建后的稳定 ID 和状态
/// - 为消息、同城履约和医疗记录回流提供关联字段
#[derive(Debug, Serialize)]
pub(super) struct HospitalAppointmentData {
    id: Uuid,
    owner_user_id: Uuid,
    pet_id: Option<Uuid>,
    hospital_id: Uuid,
    scheduled_at: DateTime<Utc>,
    reason: String,
    note: Option<String>,
    status: String,
}

impl From<HospitalAppointment> for HospitalAppointmentData {
    fn from(appointment: HospitalAppointment) -> Self {
        Self {
            id: appointment.id,
            owner_user_id: appointment.owner_user_id,
            pet_id: appointment.pet_id,
            hospital_id: appointment.hospital_id,
            scheduled_at: appointment.scheduled_at,
            reason: appointment.reason,
            note: appointment.note,
            status: appointment.status.as_str().to_owned(),
        }
    }
}
