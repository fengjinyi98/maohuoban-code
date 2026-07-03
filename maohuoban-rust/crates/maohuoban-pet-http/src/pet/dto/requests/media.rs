use axum::extract::Multipart;
use maohuoban_pet_application::pet::{
    MediaCropMetadata, PendingPetLivePhotoUploadInput, PendingPetMediaUploadInput,
};
use maohuoban_pet_domain::pet::{MediaUsageKind, PetError, PetResult};
use uuid::Uuid;

/// UploadPetMediaRequest 上传宠物媒体请求
/// 核心职责：
/// - 承接 multipart 解包后的媒体内容
/// - 转换为媒体资产和业务绑定命令
#[derive(Debug)]
pub(crate) struct UploadPetMediaRequest {
    file_name: String,
    mime_type: String,
    content: Vec<u8>,
    source_client: Option<String>,
}

/// UploadPetLivePhotoRequest 上传宠物 Live Photo 请求
/// 核心职责：
/// - 承接静态图和配对视频 multipart 字段
/// - 转换为 Live Photo 背景上传命令
#[derive(Debug)]
pub(crate) struct UploadPetLivePhotoRequest {
    still_file_name: String,
    still_mime_type: String,
    still_content: Vec<u8>,
    paired_video_file_name: String,
    paired_video_mime_type: String,
    paired_video_content: Vec<u8>,
    source_client: Option<String>,
    crop_metadata: Option<MediaCropMetadata>,
}

impl UploadPetMediaRequest {
    pub(crate) async fn from_multipart(mut multipart: Multipart) -> PetResult<Self> {
        let mut file_name = None;
        let mut mime_type = None;
        let mut content = None;
        let mut source_client = None;

        while let Some(field) = multipart
            .next_field()
            .await
            .map_err(|_| PetError::InvalidInput("媒体上传表单无法解析".to_owned()))?
        {
            match field.name() {
                Some("file") => {
                    file_name = Some(
                        field
                            .file_name()
                            .filter(|value| !value.trim().is_empty())
                            .unwrap_or("upload.bin")
                            .to_owned(),
                    );
                    mime_type = Some(
                        field
                            .content_type()
                            .filter(|value| !value.trim().is_empty())
                            .unwrap_or("application/octet-stream")
                            .to_owned(),
                    );
                    let bytes = field
                        .bytes()
                        .await
                        .map_err(|_| PetError::InvalidInput("媒体文件读取失败".to_owned()))?;
                    content = Some(bytes.to_vec());
                }
                Some("source_client") => {
                    let value = field
                        .text()
                        .await
                        .map_err(|_| PetError::InvalidInput("媒体来源客户端读取失败".to_owned()))?;
                    let trimmed = value.trim();
                    if !trimmed.is_empty() {
                        source_client = Some(trimmed.to_owned());
                    }
                }
                _ => {}
            }
        }

        let content = content.ok_or_else(|| PetError::InvalidInput("请上传媒体文件".to_owned()))?;
        if content.is_empty() {
            return Err(PetError::InvalidInput("媒体文件不能为空".to_owned()));
        }

        Ok(Self {
            file_name: file_name.unwrap_or_else(|| "upload.bin".to_owned()),
            mime_type: mime_type.unwrap_or_else(|| "application/octet-stream".to_owned()),
            content,
            source_client,
        })
    }

    pub(crate) fn into_pending_avatar_input(
        self,
        owner_user_id: Uuid,
    ) -> PendingPetMediaUploadInput {
        self.into_pending_input(owner_user_id, MediaUsageKind::PetAvatar)
    }

    pub(crate) fn into_pending_background_image_input(
        self,
        owner_user_id: Uuid,
    ) -> PendingPetMediaUploadInput {
        self.into_pending_input(owner_user_id, MediaUsageKind::PetBackgroundImage)
    }

    pub(crate) fn into_pending_background_video_input(
        self,
        owner_user_id: Uuid,
    ) -> PendingPetMediaUploadInput {
        self.into_pending_input(owner_user_id, MediaUsageKind::PetBackgroundVideo)
    }

    pub(in crate::pet::dto::requests) fn into_pending_input(
        self,
        owner_user_id: Uuid,
        usage_kind: MediaUsageKind,
    ) -> PendingPetMediaUploadInput {
        PendingPetMediaUploadInput {
            owner_user_id,
            usage_kind,
            file_name: self.file_name,
            mime_type: self.mime_type,
            content: self.content,
            source_client: self.source_client,
        }
    }
}

impl UploadPetLivePhotoRequest {
    pub(crate) async fn from_multipart(mut multipart: Multipart) -> PetResult<Self> {
        let mut still_file = None;
        let mut paired_video_file = None;
        let mut source_client = None;
        let mut crop_x = None;
        let mut crop_y = None;
        let mut crop_width = None;
        let mut crop_height = None;

        while let Some(field) = multipart
            .next_field()
            .await
            .map_err(|_| PetError::InvalidInput("Live Photo 上传表单无法解析".to_owned()))?
        {
            match field.name() {
                Some("still_file") => {
                    still_file = Some(read_upload_field(field, "live-still.bin").await?);
                }
                Some("paired_video_file") => {
                    paired_video_file = Some(read_upload_field(field, "live-motion.mov").await?);
                }
                Some("source_client") => {
                    let value = field
                        .text()
                        .await
                        .map_err(|_| PetError::InvalidInput("媒体来源客户端读取失败".to_owned()))?;
                    let trimmed = value.trim();
                    if !trimmed.is_empty() {
                        source_client = Some(trimmed.to_owned());
                    }
                }
                Some("crop_x") => {
                    crop_x = Some(read_crop_number_field(field, "crop_x").await?);
                }
                Some("crop_y") => {
                    crop_y = Some(read_crop_number_field(field, "crop_y").await?);
                }
                Some("crop_width") => {
                    crop_width = Some(read_crop_number_field(field, "crop_width").await?);
                }
                Some("crop_height") => {
                    crop_height = Some(read_crop_number_field(field, "crop_height").await?);
                }
                _ => {}
            }
        }

        let still_file = still_file
            .ok_or_else(|| PetError::InvalidInput("请上传 Live Photo 静态图".to_owned()))?;
        let paired_video_file = paired_video_file
            .ok_or_else(|| PetError::InvalidInput("请上传 Live Photo 配对视频".to_owned()))?;
        if still_file.content.is_empty() || paired_video_file.content.is_empty() {
            return Err(PetError::InvalidInput("Live Photo 资源不能为空".to_owned()));
        }

        Ok(Self {
            still_file_name: still_file.file_name,
            still_mime_type: still_file.mime_type,
            still_content: still_file.content,
            paired_video_file_name: paired_video_file.file_name,
            paired_video_mime_type: paired_video_file.mime_type,
            paired_video_content: paired_video_file.content,
            source_client,
            crop_metadata: build_crop_metadata(crop_x, crop_y, crop_width, crop_height)?,
        })
    }

    pub(crate) fn into_pending_live_photo_input(
        self,
        owner_user_id: Uuid,
    ) -> PendingPetLivePhotoUploadInput {
        PendingPetLivePhotoUploadInput {
            owner_user_id,
            still_file_name: self.still_file_name,
            still_mime_type: self.still_mime_type,
            still_content: self.still_content,
            paired_video_file_name: self.paired_video_file_name,
            paired_video_mime_type: self.paired_video_mime_type,
            paired_video_content: self.paired_video_content,
            source_client: self.source_client,
            crop_metadata: self.crop_metadata,
        }
    }
}

async fn read_crop_number_field(
    field: axum::extract::multipart::Field<'_>,
    name: &str,
) -> PetResult<f64> {
    let value = field
        .text()
        .await
        .map_err(|_| PetError::InvalidInput(format!("{name} 读取失败")))?;
    let parsed = value
        .trim()
        .parse::<f64>()
        .map_err(|_| PetError::InvalidInput(format!("{name} 必须是数字")))?;
    if !(0.0..=1.0).contains(&parsed) {
        return Err(PetError::InvalidInput(format!("{name} 必须在 0 到 1 之间")));
    }
    Ok(parsed)
}

fn build_crop_metadata(
    crop_x: Option<f64>,
    crop_y: Option<f64>,
    crop_width: Option<f64>,
    crop_height: Option<f64>,
) -> PetResult<Option<MediaCropMetadata>> {
    match (crop_x, crop_y, crop_width, crop_height) {
        (None, None, None, None) => Ok(None),
        (Some(x), Some(y), Some(width), Some(height))
            if width > 0.0 && height > 0.0 && x + width <= 1.0 && y + height <= 1.0 =>
        {
            Ok(Some(MediaCropMetadata {
                x,
                y,
                width,
                height,
            }))
        }
        (Some(_), Some(_), Some(_), Some(_)) => Err(PetError::InvalidInput(
            "裁剪区域必须位于图像范围内".to_owned(),
        )),
        _ => Err(PetError::InvalidInput(
            "Live Photo 裁剪字段不完整".to_owned(),
        )),
    }
}

/// MultipartUploadFile multipart 文件字段
/// 核心职责：
/// - 保存单个上传字段的文件名、媒体类型和内容
/// - 复用 Live Photo 成对字段读取逻辑
struct MultipartUploadFile {
    file_name: String,
    mime_type: String,
    content: Vec<u8>,
}

async fn read_upload_field(
    field: axum::extract::multipart::Field<'_>,
    fallback_file_name: &str,
) -> PetResult<MultipartUploadFile> {
    let file_name = field
        .file_name()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or(fallback_file_name)
        .to_owned();
    let mime_type = field
        .content_type()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or("application/octet-stream")
        .to_owned();
    let bytes = field
        .bytes()
        .await
        .map_err(|_| PetError::InvalidInput("媒体文件读取失败".to_owned()))?;
    Ok(MultipartUploadFile {
        file_name,
        mime_type,
        content: bytes.to_vec(),
    })
}
