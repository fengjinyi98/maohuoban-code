use chrono::NaiveDate;
use maohuoban_profile_domain::profile::{
    AvatarPresentation, ProfileError, ProfileFieldEditPolicy, ProfileMediaAsset, UserGender,
    UserProfile,
};
use serde::Serialize;

/// `CurrentProfileData` 当前用户资料响应
/// 核心职责：
/// - 返回编辑资料页和我的页所需的资料字段
/// - 避免公开注册序号和勋章数组
#[derive(Debug, Serialize)]
pub(super) struct CurrentProfileData {
    user_id: String,
    maohuoban_id: String,
    display_name: String,
    default_display_name: String,
    bio: Option<String>,
    gender: &'static str,
    is_gender_visible: bool,
    birthday: Option<String>,
    birthday_display_text: Option<String>,
    avatar: Option<ProfileMediaData>,
    cover: Option<ProfileMediaData>,
    avatar_presentation: AvatarPresentation,
    display_name_edit_policy: Option<ProfileFieldEditPolicy>,
    bio_edit_policy: Option<ProfileFieldEditPolicy>,
}

impl From<UserProfile> for CurrentProfileData {
    fn from(profile: UserProfile) -> Self {
        let avatar_presentation = profile.avatar_presentation();
        let birthday = profile.birthday.map(|date| date.to_string());
        Self {
            user_id: profile.user_id.to_string(),
            maohuoban_id: profile.maohuoban_id,
            display_name: profile.display_name,
            default_display_name: profile.default_display_name,
            bio: profile.bio,
            gender: profile.gender.as_str(),
            is_gender_visible: profile.is_gender_visible,
            birthday: birthday.clone(),
            birthday_display_text: birthday,
            avatar: profile.avatar.map(ProfileMediaData::from),
            cover: profile.cover.map(ProfileMediaData::from),
            avatar_presentation,
            display_name_edit_policy: profile.display_name_edit_policy,
            bio_edit_policy: profile.bio_edit_policy,
        }
    }
}

/// `ProfileMediaData` 用户资料媒体响应
/// 核心职责：
/// - 向前端输出可直接展示的媒资字段
/// - 保持响应字段名和 iOS 解码模型稳定
#[derive(Debug, Serialize)]
pub(super) struct ProfileMediaData {
    asset_id: String,
    url: String,
    width: Option<i32>,
    height: Option<i32>,
    mime_type: String,
    updated_at: chrono::DateTime<chrono::Utc>,
}

impl From<ProfileMediaAsset> for ProfileMediaData {
    fn from(asset: ProfileMediaAsset) -> Self {
        Self {
            asset_id: asset.asset_id.to_string(),
            url: asset.url,
            width: asset.width,
            height: asset.height,
            mime_type: asset.mime_type,
            updated_at: asset.updated_at,
        }
    }
}

pub(super) fn parse_gender(value: &str) -> Result<UserGender, ProfileError> {
    match value {
        "male" => Ok(UserGender::Male),
        "female" => Ok(UserGender::Female),
        "unknown" => Ok(UserGender::Unknown),
        _ => Err(ProfileError::GenderInvalid),
    }
}

pub(super) fn parse_birthday(value: &str) -> Result<NaiveDate, ProfileError> {
    NaiveDate::parse_from_str(value, "%Y-%m-%d").map_err(|_| ProfileError::BirthdayInvalid)
}
