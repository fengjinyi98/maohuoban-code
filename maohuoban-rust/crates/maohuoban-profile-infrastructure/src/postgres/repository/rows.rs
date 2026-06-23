use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_profile_domain::profile::{ProfileMediaAsset, UserGender, UserProfile};
use sqlx::FromRow;
use uuid::Uuid;

/// `UserProfileRow` 用户资料数据库行
/// 核心职责：
/// - 承接 `user_profiles` 查询结果
/// - 转换为资料领域实体
#[derive(Debug, FromRow)]
pub(super) struct UserProfileRow {
    user_id: Uuid,
    maohuoban_id: String,
    display_name: String,
    default_display_name: String,
    bio: Option<String>,
    gender: String,
    is_gender_visible: bool,
    birthday: Option<NaiveDate>,
    avatar_asset_id: Option<Uuid>,
    cover_asset_id: Option<Uuid>,
}

impl From<UserProfileRow> for UserProfile {
    fn from(row: UserProfileRow) -> Self {
        Self {
            user_id: row.user_id,
            maohuoban_id: row.maohuoban_id,
            display_name: row.display_name,
            default_display_name: row.default_display_name,
            bio: row.bio,
            gender: UserGender::from(row.gender.as_str()),
            is_gender_visible: row.is_gender_visible,
            birthday: row.birthday,
            avatar_asset_id: row.avatar_asset_id,
            cover_asset_id: row.cover_asset_id,
            avatar: None,
            cover: None,
            display_name_edit_policy: None,
            bio_edit_policy: None,
        }
    }
}

/// `ProfileMediaAssetRow` 用户资料媒体资产数据库行
/// 核心职责：
/// - 承接 `media_assets` 中用户头像和背景所需字段
/// - 转换为前端可展示的资料媒体实体
#[derive(Debug, FromRow)]
pub(super) struct ProfileMediaAssetRow {
    id: Uuid,
    mime_type: String,
    width: Option<i32>,
    height: Option<i32>,
    updated_at: DateTime<Utc>,
}

impl From<ProfileMediaAssetRow> for ProfileMediaAsset {
    fn from(row: ProfileMediaAssetRow) -> Self {
        Self {
            asset_id: row.id,
            url: format!("/api/v1/media/assets/{}/content", row.id),
            width: row.width,
            height: row.height,
            mime_type: row.mime_type,
            updated_at: row.updated_at,
        }
    }
}
