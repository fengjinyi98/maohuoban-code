use chrono::NaiveDate;
use maohuoban_profile_domain::profile::{UserGender, UserProfile};
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
            display_name_edit_policy: None,
            bio_edit_policy: None,
        }
    }
}
