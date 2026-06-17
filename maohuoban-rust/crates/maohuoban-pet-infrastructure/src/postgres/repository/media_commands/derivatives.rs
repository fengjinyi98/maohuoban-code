use std::{
    env, fs,
    process::{Command, Stdio},
};

use maohuoban_media_storage::MediaObjectStore;
use maohuoban_pet_domain::pet::{MediaDerivativeKind, PetError, PetResult};
use serde_json::Value;
use uuid::Uuid;

use super::{MediaUploadObjectInput, PreparedMediaDerivative, PreparedMediaObject};
use crate::postgres::repository::storage::{sanitized_file_name, sha256_hex};

/// prepare_video_derivatives 生成视频派生对象
/// 核心职责：
/// - 使用 ffmpeg 提取视频第一帧
/// - 复用图片派生逻辑生成封面帧和主题色
pub(super) async fn prepare_video_derivatives(
    media_store: &MediaObjectStore,
    input: &MediaUploadObjectInput<'_>,
    media: &PreparedMediaObject,
) -> PetResult<Vec<PreparedMediaDerivative>> {
    let Some(frame_content) = extract_first_video_frame(input.content, input.file_name) else {
        return Ok(Vec::new());
    };
    let Ok(frame) = image::load_from_memory(&frame_content) else {
        return Ok(Vec::new());
    };

    let theme_color = average_theme_color(&frame);
    let theme_payload = serde_json::json!({ "theme_color_hex": theme_color }).to_string();

    Ok(vec![
        prepare_derivative_object(
            media_store,
            media,
            MediaDerivativeKind::VideoCoverFrame,
            "cover-frame.png",
            "image/png",
            frame_content,
            serde_json::json!({
                "width": frame.width(),
                "height": frame.height()
            }),
        )
        .await?,
        prepare_derivative_object(
            media_store,
            media,
            MediaDerivativeKind::ThemeColorFrame,
            "theme-color.json",
            "application/json",
            theme_payload.into_bytes(),
            serde_json::json!({ "theme_color_hex": theme_color }),
        )
        .await?,
    ])
}

/// extract_first_video_frame 提取视频首帧
/// 核心职责：
/// - 将上传视频写入临时文件
/// - 调用 ffmpeg 输出单帧 PNG 字节
fn extract_first_video_frame(content: &[u8], file_name: &str) -> Option<Vec<u8>> {
    let ffmpeg_path = env::var("MAOHUOBAN_FFMPEG_PATH").unwrap_or_else(|_| "ffmpeg".to_owned());
    let token = Uuid::new_v4();
    let sanitized_name = sanitized_file_name(file_name);
    let extension = sanitized_name
        .rsplit_once('.')
        .map_or("mp4", |(_, extension)| extension);
    let input_path = env::temp_dir().join(format!("maohuoban-video-{token}.{extension}"));
    let frame_path = env::temp_dir().join(format!("maohuoban-video-frame-{token}.png"));

    if fs::write(&input_path, content).is_err() {
        return None;
    }

    let status = Command::new(ffmpeg_path)
        .arg("-v")
        .arg("error")
        .arg("-y")
        .arg("-i")
        .arg(&input_path)
        .arg("-frames:v")
        .arg("1")
        .arg(&frame_path)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .ok();
    let frame_content = status
        .filter(std::process::ExitStatus::success)
        .and_then(|_| fs::read(&frame_path).ok());

    let _ = fs::remove_file(input_path);
    let _ = fs::remove_file(frame_path);
    frame_content
}

/// average_theme_color 计算图片平均主题色
/// 核心职责：
/// - 从可解码图片中提取稳定十六进制颜色
/// - 为媒体派生 metadata 提供前端可直接使用的主题色
pub(super) fn average_theme_color(image: &image::DynamicImage) -> String {
    let rgb_image = image.to_rgb8();
    let pixel_count = u64::from(rgb_image.width()) * u64::from(rgb_image.height());
    if pixel_count == 0 {
        return "#000000".to_owned();
    }

    let (red, green, blue) =
        rgb_image
            .pixels()
            .fold((0_u64, 0_u64, 0_u64), |(red, green, blue), pixel| {
                (
                    red + u64::from(pixel[0]),
                    green + u64::from(pixel[1]),
                    blue + u64::from(pixel[2]),
                )
            });
    format!(
        "#{:02X}{:02X}{:02X}",
        red / pixel_count,
        green / pixel_count,
        blue / pixel_count
    )
}

/// prepare_derivative_object 持久化单个派生对象
/// 核心职责：
/// - 生成派生对象 key、哈希和大小
/// - 写入对象根并返回数据库记录输入
pub(super) async fn prepare_derivative_object(
    media_store: &MediaObjectStore,
    media: &PreparedMediaObject,
    derivative_kind: MediaDerivativeKind,
    file_name: &str,
    mime_type: &str,
    content: Vec<u8>,
    metadata: Value,
) -> PetResult<PreparedMediaDerivative> {
    let id = Uuid::new_v4();
    let object_prefix = media
        .object_key
        .rsplit_once('/')
        .map_or(media.object_key.as_str(), |(prefix, _)| prefix);
    let object_key = format!(
        "{}/derivatives/{}/{}",
        object_prefix,
        derivative_kind.as_str(),
        file_name
    );
    media_store
        .put(&media.bucket, &object_key, &content)
        .await
        .map_err(|error| PetError::Infrastructure(error.to_string()))?;
    let byte_size = i64::try_from(content.len())
        .map_err(|_| PetError::InvalidInput("媒体派生内容过大".to_owned()))?;

    Ok(PreparedMediaDerivative {
        id,
        derivative_kind,
        bucket: media.bucket.clone(),
        object_key,
        mime_type: mime_type.to_owned(),
        byte_size,
        sha256_hex: sha256_hex(&content),
        metadata,
    })
}
