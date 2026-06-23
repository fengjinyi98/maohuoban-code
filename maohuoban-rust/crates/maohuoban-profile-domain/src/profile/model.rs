use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// `UserGender` 用户性别
/// 核心职责：
/// - 固定后端存储和接口输出的性别枚举
/// - 为头像框展示规则提供统一输入
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UserGender {
    Male,
    Female,
    Unknown,
}

impl UserGender {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Male => "male",
            Self::Female => "female",
            Self::Unknown => "unknown",
        }
    }
}

impl From<&str> for UserGender {
    fn from(value: &str) -> Self {
        match value {
            "male" => Self::Male,
            "female" => Self::Female,
            _ => Self::Unknown,
        }
    }
}

/// `AvatarSex` 头像框性别展示值
/// 核心职责：
/// - 固定客户端头像组件消费的性别字段
/// - 屏蔽用户保密和关闭展示后的原始性别
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum AvatarSex {
    Male,
    Female,
    Unknown,
}

/// `AvatarSexVisibility` 头像框性别展示状态
/// 核心职责：
/// - 表达头像框是否展示性别标记
/// - 让客户端无需重复判断性别和展示开关
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum AvatarSexVisibility {
    Visible,
    Hidden,
}

/// `AvatarPresentation` 用户头像展示规则
/// 核心职责：
/// - 汇总头像框所需展示字段
/// - 将隐私规则收敛在后端资料域
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct AvatarPresentation {
    pub sex: AvatarSex,
    pub sex_visibility: AvatarSexVisibility,
}

impl AvatarPresentation {
    #[must_use]
    pub const fn from_gender(gender: UserGender, is_gender_visible: bool) -> Self {
        if !is_gender_visible {
            return Self {
                sex: AvatarSex::Unknown,
                sex_visibility: AvatarSexVisibility::Hidden,
            };
        }

        match gender {
            UserGender::Male => Self {
                sex: AvatarSex::Male,
                sex_visibility: AvatarSexVisibility::Visible,
            },
            UserGender::Female => Self {
                sex: AvatarSex::Female,
                sex_visibility: AvatarSexVisibility::Visible,
            },
            UserGender::Unknown => Self {
                sex: AvatarSex::Unknown,
                sex_visibility: AvatarSexVisibility::Hidden,
            },
        }
    }
}

/// `UserProfile` 用户资料实体
/// 核心职责：
/// - 承载当前用户资料的后端事实源
/// - 提供客户端头像框可直接消费的派生展示字段
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct UserProfile {
    pub user_id: Uuid,
    pub maohuoban_id: String,
    pub display_name: String,
    pub default_display_name: String,
    pub bio: Option<String>,
    pub gender: UserGender,
    pub is_gender_visible: bool,
    pub birthday: Option<NaiveDate>,
    pub avatar_asset_id: Option<Uuid>,
    pub cover_asset_id: Option<Uuid>,
    pub avatar: Option<ProfileMediaAsset>,
    pub cover: Option<ProfileMediaAsset>,
    pub display_name_edit_policy: Option<ProfileFieldEditPolicy>,
    pub bio_edit_policy: Option<ProfileFieldEditPolicy>,
}

impl UserProfile {
    #[must_use]
    pub const fn avatar_presentation(&self) -> AvatarPresentation {
        AvatarPresentation::from_gender(self.gender, self.is_gender_visible)
    }
}

/// `ProfileMediaAsset` 用户资料媒体资产
/// 核心职责：
/// - 表达头像和主页背景的可展示媒资字段
/// - 隐藏对象存储 bucket 和 object key 等内部细节
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ProfileMediaAsset {
    pub asset_id: Uuid,
    pub url: String,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub mime_type: String,
    pub updated_at: DateTime<Utc>,
}

/// `ProfileFieldEditPolicy` 用户资料字段编辑策略
/// 核心职责：
/// - 表达后端计算出的字段修改额度
/// - 为前端编辑页展示和禁用态提供直接消费的数据
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ProfileFieldEditPolicy {
    pub max_count: i32,
    pub used_count: i32,
    pub remaining_count: i32,
    pub window_days: i32,
    pub window_ends_at: Option<DateTime<Utc>>,
    pub display_text: String,
}
