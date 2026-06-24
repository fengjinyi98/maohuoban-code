use axum::extract::Multipart;
use maohuoban_profile_application::profile::{ProfileMediaKind, UploadProfileMediaInput};
use maohuoban_profile_domain::profile::ProfileError;
use serde::Deserialize;
use uuid::Uuid;

/// `UploadProfileMediaRequest` 用户资料媒体上传请求
/// 核心职责：
/// - 承接 multipart 解包后的图片字段
/// - 转换为应用层用户资料媒体上传命令
#[derive(Debug)]
pub(super) struct UploadProfileMediaRequest {
    file_name: String,
    mime_type: String,
    content: Vec<u8>,
    source_client: Option<String>,
}

impl UploadProfileMediaRequest {
    pub(super) async fn from_multipart(mut multipart: Multipart) -> Result<Self, ProfileError> {
        let mut file_name = None;
        let mut mime_type = None;
        let mut content = None;
        let mut source_client = None;

        while let Some(field) = multipart
            .next_field()
            .await
            .map_err(|_| ProfileError::MediaMultipartInvalid)?
        {
            match field.name() {
                Some("file") => {
                    file_name = Some(
                        field
                            .file_name()
                            .filter(|v| !v.trim().is_empty())
                            .unwrap_or("profile-media.bin")
                            .to_owned(),
                    );
                    mime_type = Some(
                        field
                            .content_type()
                            .filter(|v| !v.trim().is_empty())
                            .unwrap_or("application/octet-stream")
                            .to_owned(),
                    );
                    let bytes = field
                        .bytes()
                        .await
                        .map_err(|_| ProfileError::MediaMultipartInvalid)?;
                    content = Some(bytes.to_vec());
                }
                Some("source_client") => {
                    let value = field
                        .text()
                        .await
                        .map_err(|_| ProfileError::MediaMultipartInvalid)?;
                    let trimmed = value.trim();
                    if !trimmed.is_empty() {
                        source_client = Some(trimmed.to_owned());
                    }
                }
                _ => {}
            }
        }

        Ok(Self {
            file_name: file_name.unwrap_or_else(|| "profile-media.bin".to_owned()),
            mime_type: mime_type.unwrap_or_else(|| "application/octet-stream".to_owned()),
            content: content.ok_or(ProfileError::MediaFileRequired)?,
            source_client,
        })
    }

    pub(super) fn into_input(
        self,
        user_id: Uuid,
        kind: ProfileMediaKind,
    ) -> UploadProfileMediaInput {
        UploadProfileMediaInput {
            user_id,
            kind,
            file_name: self.file_name,
            mime_type: self.mime_type,
            content: self.content,
            source_client: self.source_client,
        }
    }
}

/// `UpdateCurrentProfileRequest` 当前用户资料更新请求
/// 核心职责：
/// - 接收个人资料页可编辑字段的局部更新
/// - 将 HTTP 字符串字段转换为应用层输入
#[derive(Debug, Deserialize)]
pub(super) struct UpdateCurrentProfileRequest {
    pub(super) display_name: Option<String>,
    pub(super) bio: Option<String>,
    pub(super) gender: Option<String>,
    pub(super) is_gender_visible: Option<bool>,
    pub(super) birthday: Option<String>,
}

impl UpdateCurrentProfileRequest {
    pub(super) fn into_input(
        self,
        user_id: Uuid,
    ) -> Result<maohuoban_profile_application::profile::UpdateProfileInput, ProfileError> {
        Ok(maohuoban_profile_application::profile::UpdateProfileInput {
            user_id,
            display_name: self.display_name,
            bio: self.bio,
            gender: self
                .gender
                .map(|g| super::mappers::parse_gender(&g))
                .transpose()?,
            is_gender_visible: self.is_gender_visible,
            birthday: self
                .birthday
                .map(|b| super::mappers::parse_birthday(&b))
                .transpose()?,
        })
    }
}
