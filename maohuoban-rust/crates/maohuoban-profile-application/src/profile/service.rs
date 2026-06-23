use std::sync::Arc;

use chrono::{NaiveDate, Utc};
use maohuoban_profile_domain::profile::{ProfileError, ProfileResult, UserProfile};
use uuid::Uuid;

use super::{
    DefaultProfileInput, ProfileMediaUploadDiagnostics, ProfileRepository, UpdateProfileInput,
    UploadProfileMediaInput, profile_error_kind, profile_media_content_signature,
    record_profile_media_upload,
};

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

    /// # Errors
    /// 当资料不存在、上传文件不合法或仓储写入失败时返回错误。
    pub async fn upload_current_profile_media(
        &self,
        input: UploadProfileMediaInput,
    ) -> ProfileResult<UserProfile> {
        let user_id = input.user_id;
        let kind = input.kind;
        let declared_mime_type = input.mime_type.clone();
        let byte_size = i64::try_from(input.content.len()).unwrap_or(i64::MAX);
        let content_signature = profile_media_content_signature(&input.content);

        record_profile_media_upload(ProfileMediaUploadDiagnostics {
            stage: "service.request",
            user_id,
            asset_id: None,
            kind,
            declared_mime_type: &declared_mime_type,
            byte_size,
            content_signature: Some(content_signature),
            width: None,
            height: None,
            success: true,
            error_kind: None,
            decoder_error_kind: None,
        });

        if let Err(error) = Self::validate_media_upload(&input) {
            record_profile_media_upload(ProfileMediaUploadDiagnostics {
                stage: "service.result",
                user_id,
                asset_id: None,
                kind,
                declared_mime_type: &declared_mime_type,
                byte_size,
                content_signature: Some(content_signature),
                width: None,
                height: None,
                success: false,
                error_kind: Some(profile_error_kind(&error)),
                decoder_error_kind: None,
            });
            return Err(error);
        }

        let result = self.repository.upload_profile_media(input).await;
        match &result {
            Ok(profile) => {
                let media = match kind {
                    super::ProfileMediaKind::Avatar => profile.avatar.as_ref(),
                    super::ProfileMediaKind::Cover => profile.cover.as_ref(),
                };
                record_profile_media_upload(ProfileMediaUploadDiagnostics {
                    stage: "service.result",
                    user_id,
                    asset_id: media.map(|media| media.asset_id),
                    kind,
                    declared_mime_type: media.map_or(declared_mime_type.as_str(), |media| {
                        media.mime_type.as_str()
                    }),
                    byte_size,
                    content_signature: Some(content_signature),
                    width: media.and_then(|media| media.width),
                    height: media.and_then(|media| media.height),
                    success: true,
                    error_kind: None,
                    decoder_error_kind: None,
                });
            }
            Err(error) => record_profile_media_upload(ProfileMediaUploadDiagnostics {
                stage: "service.result",
                user_id,
                asset_id: None,
                kind,
                declared_mime_type: &declared_mime_type,
                byte_size,
                content_signature: Some(content_signature),
                width: None,
                height: None,
                success: false,
                error_kind: Some(profile_error_kind(error)),
                decoder_error_kind: None,
            }),
        }
        result
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

    fn validate_media_upload(input: &UploadProfileMediaInput) -> ProfileResult<()> {
        if input.content.is_empty() {
            return Err(ProfileError::MediaFileRequired);
        }
        if input.content.len() > input.kind.size_limit_bytes() {
            return Err(ProfileError::MediaTooLarge);
        }
        if !matches!(
            input.mime_type.as_str(),
            "image/jpeg" | "image/png" | "image/webp"
        ) {
            return Err(ProfileError::MediaTypeInvalid);
        }
        Ok(())
    }
}
