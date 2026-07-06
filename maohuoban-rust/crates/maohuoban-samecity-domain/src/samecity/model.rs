use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::SameCityError;

/// Hospital 同城医院实体
/// 核心职责：
/// - 表达同城页和首页预约入口可选择的医院
/// - 保留认证状态和服务标签供后续排序推荐扩展
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Hospital {
    pub id: Uuid,
    pub name: String,
    pub city: String,
    pub district: Option<String>,
    pub address: String,
    pub phone: Option<String>,
    pub service_tags: Vec<String>,
    pub verification_status: VerificationStatus,
    pub partnership_status: HospitalPartnershipStatus,
    pub his_enabled: bool,
    pub his_tenant_id: Option<Uuid>,
    pub appointment_enabled: bool,
    pub medical_record_return_enabled: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// VerificationStatus 同城实体认证状态
/// 核心职责：
/// - 固定医院实体认证状态契约
/// - 支持首页只展示已认证实体
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum VerificationStatus {
    Pending,
    Verified,
    Rejected,
    Suspended,
}

impl VerificationStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Pending => "pending",
            Self::Verified => "verified",
            Self::Rejected => "rejected",
            Self::Suspended => "suspended",
        }
    }
}

impl TryFrom<&str> for VerificationStatus {
    type Error = SameCityError;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "pending" => Ok(Self::Pending),
            "verified" => Ok(Self::Verified),
            "rejected" => Ok(Self::Rejected),
            "suspended" => Ok(Self::Suspended),
            _ => Err(SameCityError::Infrastructure(
                "unknown verification status from database".to_owned(),
            )),
        }
    }
}

/// HospitalPartnershipStatus 医院合作状态
/// 核心职责：
/// - 区分普通认证医院和已接入闭环的合作医院
/// - 支撑 App 预约入口只展示可 HIS 回流的医院
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum HospitalPartnershipStatus {
    Candidate,
    Active,
    Suspended,
}

impl HospitalPartnershipStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Candidate => "candidate",
            Self::Active => "active",
            Self::Suspended => "suspended",
        }
    }
}

impl TryFrom<&str> for HospitalPartnershipStatus {
    type Error = SameCityError;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "candidate" => Ok(Self::Candidate),
            "active" => Ok(Self::Active),
            "suspended" => Ok(Self::Suspended),
            _ => Err(SameCityError::Infrastructure(
                "unknown partnership status from database".to_owned(),
            )),
        }
    }
}

/// HospitalAppointment 医院预约
/// 核心职责：
/// - 表达用户为宠物发起的一次同城医院预约
/// - 为后续消息沟通、履约和医院记录回流保留稳定 ID
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HospitalAppointment {
    pub id: Uuid,
    pub owner_user_id: Uuid,
    pub pet_id: Option<Uuid>,
    pub hospital_id: Uuid,
    pub scheduled_at: DateTime<Utc>,
    pub reason: String,
    pub note: Option<String>,
    pub status: HospitalAppointmentStatus,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// HospitalAppointmentStatus 医院预约状态
/// 核心职责：
/// - 固定预约状态机的首批状态
/// - 让后续医院确认、取消和完成流程可渐进扩展
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum HospitalAppointmentStatus {
    Pending,
    Confirmed,
    Cancelled,
    Completed,
}

impl HospitalAppointmentStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Pending => "pending",
            Self::Confirmed => "confirmed",
            Self::Cancelled => "cancelled",
            Self::Completed => "completed",
        }
    }
}

impl TryFrom<&str> for HospitalAppointmentStatus {
    type Error = SameCityError;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "pending" => Ok(Self::Pending),
            "confirmed" => Ok(Self::Confirmed),
            "cancelled" => Ok(Self::Cancelled),
            "completed" => Ok(Self::Completed),
            _ => Err(SameCityError::Infrastructure(
                "unknown appointment status from database".to_owned(),
            )),
        }
    }
}
