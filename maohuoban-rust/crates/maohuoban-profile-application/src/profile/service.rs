use std::sync::Arc;

use chrono::{NaiveDate, Utc};
use maohuoban_profile_domain::profile::{ProfileError, ProfileResult, UserProfile};
use uuid::Uuid;

use super::{DefaultProfileInput, ProfileRepository, UpdateProfileInput};

/// `ProfileService` 用户资料应用服务
/// 核心职责：
/// - 为当前用户读取唯一资料事实源
/// - 幂等初始化手机号登录后生成的默认资料
#[derive(Clone)]
pub struct ProfileService {
    repository: Arc<dyn ProfileRepository>,
}

impl ProfileService {
    #[must_use]
    pub const fn new(repository: Arc<dyn ProfileRepository>) -> Self {
        Self { repository }
    }

    /// # Errors
    /// 当资料仓储读取或默认资料创建失败时返回错误。
    pub async fn ensure_default_profile(&self, user_id: Uuid) -> ProfileResult<UserProfile> {
        if let Some(profile) = self.repository.find_by_user_id(user_id).await? {
            return Ok(profile);
        }

        self.repository
            .create_default_profile(DefaultProfileInput { user_id })
            .await
    }

    /// # Errors
    /// 当资料不存在或资料仓储读取失败时返回错误。
    pub async fn current_profile(&self, user_id: Uuid) -> ProfileResult<UserProfile> {
        self.repository
            .find_by_user_id(user_id)
            .await?
            .ok_or(ProfileError::NotFound)
    }

    /// # Errors
    /// 当资料不存在、输入不合法或仓储更新失败时返回错误。
    pub async fn update_current_profile(
        &self,
        input: UpdateProfileInput,
    ) -> ProfileResult<UserProfile> {
        let normalized = Self::normalize_update(input)?;
        self.repository.update_profile(normalized).await
    }

    fn normalize_update(mut input: UpdateProfileInput) -> ProfileResult<UpdateProfileInput> {
        if let Some(display_name) = input.display_name.take() {
            input.display_name = Some(Self::normalize_display_name(&display_name)?);
        }
        if let Some(bio) = input.bio.take() {
            input.bio = Some(Self::normalize_bio(&bio)?);
        }
        if let Some(birthday) = input.birthday {
            Self::validate_birthday(birthday)?;
        }
        Ok(input)
    }

    fn normalize_display_name(value: &str) -> ProfileResult<String> {
        let trimmed = value.trim().to_owned();
        let length = trimmed.chars().count();
        if !(2..=24).contains(&length) {
            return Err(ProfileError::DisplayNameInvalid);
        }
        if trimmed
            .chars()
            .any(|character| character.is_control() || matches!(character, '@' | '<' | '>' | '/'))
        {
            return Err(ProfileError::DisplayNameInvalid);
        }
        Ok(trimmed)
    }

    fn normalize_bio(value: &str) -> ProfileResult<String> {
        let trimmed = value.trim().to_owned();
        if trimmed.chars().count() > 100 {
            return Err(ProfileError::BioInvalid);
        }
        Ok(trimmed)
    }

    fn validate_birthday(value: NaiveDate) -> ProfileResult<()> {
        let today = Utc::now().date_naive();
        let earliest = NaiveDate::from_ymd_opt(1900, 1, 1).ok_or(ProfileError::BirthdayInvalid)?;
        if value < earliest || value > today {
            return Err(ProfileError::BirthdayInvalid);
        }
        Ok(())
    }
}
