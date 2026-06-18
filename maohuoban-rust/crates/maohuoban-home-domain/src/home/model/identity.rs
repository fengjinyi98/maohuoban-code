use serde::{Deserialize, Serialize};

/// HomeIdentity 首页身份摘要
/// 核心职责：
/// - 表达当前首页形态
/// - 为普通用户、空态和认证商家切换提供稳定字段
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomeIdentity {
    pub kind: HomeIdentityKind,
    pub display_name: String,
    pub city: Option<String>,
    pub verification_badge: Option<String>,
}

/// HomeIdentityKind 首页身份类型
/// 核心职责：
/// - 固定首页形态枚举
/// - 驱动客户端选择普通首页、空态或商家工作台
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum HomeIdentityKind {
    NewUser,
    PetOwner,
    FamilyCaretaker,
    CertifiedMerchant,
    UnverifiedMerchant,
}
