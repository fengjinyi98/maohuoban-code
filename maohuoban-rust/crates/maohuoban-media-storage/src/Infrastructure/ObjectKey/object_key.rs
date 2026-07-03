use chrono::{DateTime, Datelike, Utc};
use uuid::Uuid;

/// MediaObjectKind 媒体对象类型
/// 核心职责：
/// - 区分原始对象与标准派生对象
/// - 固定跨业务媒资对象文件名契约
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MediaObjectKind<'a> {
    Original { file_name: &'a str },
    Thumbnail,
    ThemeColor,
    PairedVideo { file_name: &'a str },
    VideoCoverFrame,
}

/// traceable_media_object_key 生成可审计媒资对象路径
/// 核心职责：
/// - 统一所有业务媒资在对象存储中的路径命名
/// - 保留用户、日期和资产标识用于追溯审计
#[must_use]
pub fn traceable_media_object_key(
    owner_user_id: Uuid,
    asset_id: Uuid,
    uploaded_at: DateTime<Utc>,
    kind: MediaObjectKind<'_>,
) -> String {
    let object_file_name = match kind {
        MediaObjectKind::Original { file_name } => original_file_name(file_name),
        MediaObjectKind::Thumbnail => "thumbnail.png".to_owned(),
        MediaObjectKind::ThemeColor => "theme-color.json".to_owned(),
        MediaObjectKind::PairedVideo { file_name } => paired_video_file_name(file_name),
        MediaObjectKind::VideoCoverFrame => "video-cover-frame.png".to_owned(),
    };

    format!(
        "media/users/{}/{:04}/{:02}/{}/{}",
        owner_user_id,
        uploaded_at.year(),
        uploaded_at.month(),
        asset_id,
        object_file_name
    )
}

fn original_file_name(file_name: &str) -> String {
    let extension = file_name
        .rsplit_once('.')
        .map(|(_, extension)| extension)
        .filter(|extension| !extension.trim().is_empty())
        .map(|extension| sanitize_extension(extension).to_ascii_lowercase())
        .filter(|extension| !extension.is_empty())
        .unwrap_or_else(|| "bin".to_owned());

    format!("original.{extension}")
}

fn paired_video_file_name(file_name: &str) -> String {
    let extension = file_name
        .rsplit_once('.')
        .map(|(_, extension)| extension)
        .filter(|extension| !extension.trim().is_empty())
        .map(|extension| sanitize_extension(extension).to_ascii_lowercase())
        .filter(|extension| !extension.is_empty())
        .unwrap_or_else(|| "mov".to_owned());

    format!("paired-video.{extension}")
}

fn sanitize_extension(extension: &str) -> String {
    extension
        .chars()
        .filter(char::is_ascii_alphanumeric)
        .collect()
}
