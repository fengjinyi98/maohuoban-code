mod binding;
mod binding_assets;
mod binding_records;
mod derivatives;
mod diagnostics;
mod image_metadata;
mod live_photo_components;
mod persistence;
mod preparation;
mod upload;

use chrono::{DateTime, Utc};
use maohuoban_pet_application::pet::{MediaCropMetadata, PendingPetMediaUploadInput};
use maohuoban_pet_domain::pet::{MediaAssetComponentKind, MediaDerivativeKind, MediaUsageKind};
use serde_json::Value;
use uuid::Uuid;

/// PreparedMediaObject 已持久化媒体对象
/// 核心职责：
/// - 保存数据库写入前生成的对象存储字段
/// - 避免上传命令在事务内重复计算对象元数据
pub(super) struct PreparedMediaObject {
    pub(super) asset_id: Uuid,
    pub(super) owner_user_id: Uuid,
    pub(super) bucket: String,
    pub(super) object_key: String,
    pub(super) sha256_hex: String,
    pub(super) byte_size: i64,
    pub(super) width: Option<i32>,
    pub(super) height: Option<i32>,
    pub(super) created_at: DateTime<Utc>,
}

/// MediaUploadObjectInput 媒体对象写入上下文
/// 核心职责：
/// - 统一 pending 上传的对象字段
/// - 避免派生生成逻辑分叉
pub(super) struct MediaUploadObjectInput<'a> {
    pub(super) owner_user_id: Uuid,
    pub(super) pet_id: Option<Uuid>,
    pub(super) usage_kind: MediaUsageKind,
    pub(super) file_name: &'a str,
    pub(super) mime_type: &'a str,
    pub(super) content: &'a [u8],
    pub(super) source_client: Option<&'a str>,
    pub(super) crop_metadata: Option<MediaCropMetadata>,
}

impl<'a> From<&'a PendingPetMediaUploadInput> for MediaUploadObjectInput<'a> {
    fn from(input: &'a PendingPetMediaUploadInput) -> Self {
        Self {
            owner_user_id: input.owner_user_id,
            pet_id: None,
            usage_kind: input.usage_kind,
            file_name: &input.file_name,
            mime_type: &input.mime_type,
            content: &input.content,
            source_client: input.source_client.as_deref(),
            crop_metadata: None,
        }
    }
}

/// PreparedMediaDerivative 已持久化派生媒体对象
/// 核心职责：
/// - 保存派生对象写入后的元数据
/// - 为数据库派生记录提供统一输入
pub(super) struct PreparedMediaDerivative {
    pub(super) id: Uuid,
    pub(super) derivative_kind: MediaDerivativeKind,
    pub(super) bucket: String,
    pub(super) object_key: String,
    pub(super) mime_type: String,
    pub(super) byte_size: i64,
    pub(super) sha256_hex: String,
    pub(super) metadata: Value,
}

/// PreparedMediaComponent 已持久化媒体组件对象
/// 核心职责：
/// - 保存组合媒体组件对象字段
/// - 为 Live Photo 静态图和配对视频提供独立寻址
pub(super) struct PreparedMediaComponent {
    pub(super) id: Uuid,
    pub(super) component_kind: MediaAssetComponentKind,
    pub(super) bucket: String,
    pub(super) object_key: String,
    pub(super) mime_type: String,
    pub(super) byte_size: i64,
    pub(super) sha256_hex: String,
    pub(super) width: Option<i32>,
    pub(super) height: Option<i32>,
    pub(super) duration_ms: Option<i32>,
}
