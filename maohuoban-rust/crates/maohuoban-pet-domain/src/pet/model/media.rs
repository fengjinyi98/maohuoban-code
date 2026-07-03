use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

use super::PetErrorKind;

/// MediaAsset 媒体资产元数据
/// 核心职责：
/// - 记录对象存储位置和来源追溯字段
/// - 为绑定、替换和清理任务提供稳定资产 ID
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MediaAsset {
    pub id: Uuid,
    pub url: String,
    pub uploaded_by_user_id: Option<Uuid>,
    pub owner_pet_id: Option<Uuid>,
    pub usage_kind: MediaUsageKind,
    pub source_client: Option<String>,
    pub original_file_name: Option<String>,
    pub mime_type: String,
    pub byte_size: i64,
    pub sha256_hex: String,
    pub bucket: String,
    pub object_key: String,
    pub status: MediaAssetStatus,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub delete_after: Option<DateTime<Utc>>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// MediaBinding 媒体业务绑定
/// 核心职责：
/// - 记录媒体资产与宠物业务用途的有效关系
/// - 支持替换后追溯历史绑定
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MediaBinding {
    pub id: Uuid,
    pub asset_id: Uuid,
    pub pet_id: Uuid,
    pub usage_kind: MediaUsageKind,
    pub status: MediaBindingStatus,
    pub bound_by_user_id: Option<Uuid>,
    pub bound_at: DateTime<Utc>,
    pub replaced_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
}

/// MediaDerivative 媒体派生物
/// 核心职责：
/// - 记录缩略图、视频封面帧和主题色提取结果
/// - 为前端展示和后台清理提供派生对象追溯字段
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MediaDerivative {
    pub id: Uuid,
    pub parent_asset_id: Uuid,
    pub derivative_kind: MediaDerivativeKind,
    pub bucket: String,
    pub object_key: String,
    pub mime_type: String,
    pub byte_size: i64,
    pub sha256_hex: String,
    pub metadata: Value,
    pub created_at: DateTime<Utc>,
}

/// MediaAssetComponent 媒体资产组件
/// 核心职责：
/// - 表达 Live Photo 等组合媒体的成对对象
/// - 为前端提供组件级内容 URL 和展示元数据
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MediaAssetComponent {
    pub id: Uuid,
    pub asset_id: Uuid,
    pub url: String,
    pub component_kind: MediaAssetComponentKind,
    pub bucket: String,
    pub object_key: String,
    pub mime_type: String,
    pub byte_size: i64,
    pub sha256_hex: String,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub duration_ms: Option<i32>,
    pub created_at: DateTime<Utc>,
}

/// PetMediaUploadResult 宠物媒体上传结果
/// 核心职责：
/// - 返回新媒体资产元数据
/// - 返回当前生效业务绑定
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PetMediaUploadResult {
    pub asset: MediaAsset,
    pub binding: Option<MediaBinding>,
    pub derivatives: Vec<MediaDerivative>,
    pub components: Vec<MediaAssetComponent>,
}

/// MediaUsageKind 媒体业务用途
/// 核心职责：
/// - 固定头像、背景和相册媒体用途
/// - 驱动绑定替换和清理候选策略
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MediaUsageKind {
    #[serde(rename = "pet.avatar")]
    PetAvatar,
    #[serde(rename = "pet.background.image")]
    PetBackgroundImage,
    #[serde(rename = "pet.background.video")]
    PetBackgroundVideo,
    #[serde(rename = "pet.background.live_photo")]
    PetBackgroundLivePhoto,
    #[serde(rename = "pet.album.photo")]
    PetAlbumPhoto,
}

impl MediaUsageKind {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::PetAvatar => "pet.avatar",
            Self::PetBackgroundImage => "pet.background.image",
            Self::PetBackgroundVideo => "pet.background.video",
            Self::PetBackgroundLivePhoto => "pet.background.live_photo",
            Self::PetAlbumPhoto => "pet.album.photo",
        }
    }
}

impl TryFrom<&str> for MediaUsageKind {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "pet.avatar" => Ok(Self::PetAvatar),
            "pet.background.image" => Ok(Self::PetBackgroundImage),
            "pet.background.video" => Ok(Self::PetBackgroundVideo),
            "pet.background.live_photo" => Ok(Self::PetBackgroundLivePhoto),
            "pet.album.photo" => Ok(Self::PetAlbumPhoto),
            _ => Err(PetErrorKind::MediaUsageKind),
        }
    }
}

/// MediaAssetComponentKind 媒体资产组件类型
/// 核心职责：
/// - 固定组合媒体的组件语义
/// - 支持 Live Photo 静态图和配对视频分开寻址
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MediaAssetComponentKind {
    Still,
    PairedVideo,
}

impl MediaAssetComponentKind {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Still => "still",
            Self::PairedVideo => "paired_video",
        }
    }
}

impl TryFrom<&str> for MediaAssetComponentKind {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "still" => Ok(Self::Still),
            "paired_video" => Ok(Self::PairedVideo),
            _ => Err(PetErrorKind::MediaAssetComponentKind),
        }
    }
}

/// MediaDerivativeKind 媒体派生物类型
/// 核心职责：
/// - 固定缩略图、视频封面帧和主题色帧类型
/// - 驱动派生对象记录和前端展示选择
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MediaDerivativeKind {
    Thumbnail,
    VideoCoverFrame,
    ThemeColorFrame,
}

impl MediaDerivativeKind {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Thumbnail => "thumbnail",
            Self::VideoCoverFrame => "video_cover_frame",
            Self::ThemeColorFrame => "theme_color_frame",
        }
    }
}

impl TryFrom<&str> for MediaDerivativeKind {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "thumbnail" => Ok(Self::Thumbnail),
            "video_cover_frame" => Ok(Self::VideoCoverFrame),
            "theme_color_frame" => Ok(Self::ThemeColorFrame),
            _ => Err(PetErrorKind::MediaDerivativeKind),
        }
    }
}

/// MediaAssetStatus 媒体资产状态
/// 核心职责：
/// - 表达对象从上传到清理的生命周期
/// - 为 GC worker 领取清理候选提供状态基础
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MediaAssetStatus {
    Uploaded,
    Bound,
    CleanupPending,
    Deleted,
    Failed,
}

impl MediaAssetStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Uploaded => "uploaded",
            Self::Bound => "bound",
            Self::CleanupPending => "cleanup_pending",
            Self::Deleted => "deleted",
            Self::Failed => "failed",
        }
    }
}

impl TryFrom<&str> for MediaAssetStatus {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "uploaded" => Ok(Self::Uploaded),
            "bound" => Ok(Self::Bound),
            "cleanup_pending" => Ok(Self::CleanupPending),
            "deleted" => Ok(Self::Deleted),
            "failed" => Ok(Self::Failed),
            _ => Err(PetErrorKind::MediaAssetStatus),
        }
    }
}

/// MediaBindingStatus 媒体绑定状态
/// 核心职责：
/// - 标记当前有效、被替换和删除失效绑定
/// - 让媒体清理能只处理无有效绑定资产
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MediaBindingStatus {
    Active,
    Replaced,
    Deleted,
}

impl MediaBindingStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Active => "active",
            Self::Replaced => "replaced",
            Self::Deleted => "deleted",
        }
    }
}

impl TryFrom<&str> for MediaBindingStatus {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "active" => Ok(Self::Active),
            "replaced" => Ok(Self::Replaced),
            "deleted" => Ok(Self::Deleted),
            _ => Err(PetErrorKind::MediaBindingStatus),
        }
    }
}
