use maohuoban_pet_domain::pet::MediaUsageKind;
use uuid::Uuid;

/// MediaAssetDisplayMetadata 媒体展示元数据
/// 核心职责：
/// - 为首页和档案展示提供媒体尺寸
/// - 暴露后端派生出的主题色结果
#[derive(Debug, Clone, PartialEq)]
pub struct MediaAssetDisplayMetadata {
    pub asset_id: Uuid,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub theme_color_hex: Option<String>,
    pub crop_metadata: Option<MediaCropMetadata>,
    pub live_photo_still_url: Option<String>,
    pub live_photo_still_width: Option<i32>,
    pub live_photo_still_height: Option<i32>,
    pub live_photo_paired_video_url: Option<String>,
    pub live_photo_paired_video_width: Option<i32>,
    pub live_photo_paired_video_height: Option<i32>,
    pub live_photo_paired_video_duration_ms: Option<i32>,
}

/// MediaCropMetadata 媒体裁剪元数据
/// 核心职责：
/// - 使用归一化坐标表达客户端选择的展示裁剪区域
/// - 为 Live Photo 保留原始组件资源时提供构图契约
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct MediaCropMetadata {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

/// PendingPetMediaUploadInput 未绑定宠物媒体上传输入
/// 核心职责：
/// - 支持建档前先上传媒体资产
/// - 保持媒体资产归属和业务绑定分步完成
#[derive(Debug, Clone)]
pub struct PendingPetMediaUploadInput {
    pub owner_user_id: Uuid,
    pub usage_kind: MediaUsageKind,
    pub file_name: String,
    pub mime_type: String,
    pub content: Vec<u8>,
    pub source_client: Option<String>,
}

/// PendingPetLivePhotoUploadInput 未绑定宠物 Live Photo 上传输入
/// 核心职责：
/// - 同时承载 Live Photo 静态图和配对视频
/// - 保持组合媒体上传与单文件上传端口分离
#[derive(Debug, Clone)]
pub struct PendingPetLivePhotoUploadInput {
    pub owner_user_id: Uuid,
    pub still_file_name: String,
    pub still_mime_type: String,
    pub still_content: Vec<u8>,
    pub paired_video_file_name: String,
    pub paired_video_mime_type: String,
    pub paired_video_content: Vec<u8>,
    pub source_client: Option<String>,
    pub crop_metadata: Option<MediaCropMetadata>,
}

/// BindUploadedPetMediaInput 绑定已上传宠物媒体输入
/// 核心职责：
/// - 将 pending 媒体资产绑定到指定宠物
/// - 支持创建宠物和编辑宠物复用同一绑定能力
#[derive(Debug, Clone)]
pub struct BindUploadedPetMediaInput {
    pub pet_id: Uuid,
    pub owner_user_id: Uuid,
    pub asset_id: Uuid,
}
