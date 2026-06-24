use maohuoban_diagnostics::{DiagnosticEvent, Diagnostics, EventKind, Severity};
use maohuoban_profile_domain::profile::ProfileError;
use serde_json::{Value, json};
use uuid::Uuid;

use super::ProfileMediaKind;

/// `ProfileMediaUploadDiagnostics` 用户资料媒体上传观测输入
/// 核心职责：
/// - 描述头像和主页背景上传链路中的媒体上下文
/// - 只记录脱敏后的类型、大小、尺寸和错误分类
#[derive(Clone, Copy)]
pub struct ProfileMediaUploadDiagnostics<'a> {
    pub stage: &'a str,
    pub user_id: Uuid,
    pub asset_id: Option<Uuid>,
    pub kind: ProfileMediaKind,
    pub declared_mime_type: &'a str,
    pub byte_size: i64,
    pub content_signature: Option<&'a str>,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub success: bool,
    pub error_kind: Option<&'a str>,
    pub decoder_error_kind: Option<&'a str>,
}

/// `record_profile_media_upload` 记录用户资料媒体上传链路
/// 核心职责：
/// - 捕获 HTTP、应用服务和仓储边界的媒体状态
/// - 避免记录文件名、对象 key 和用户原始内容
pub fn record_profile_media_upload(input: ProfileMediaUploadDiagnostics<'_>) {
    let Some(diagnostics) = Diagnostics::current() else {
        return;
    };
    let mut event = DiagnosticEvent::new(
        EventKind::Analytics,
        severity(input.success),
        format!("profile.media.upload.{}", input.stage),
    )
    .metadata("stage", json!(input.stage))
    .metadata("user_id_prefix", json!(uuid_prefix(input.user_id)))
    .metadata("media_kind", json!(input.kind.path_segment()))
    .metadata("usage_kind", json!(input.kind.usage_kind()))
    .metadata("declared_mime_type", json!(input.declared_mime_type))
    .metadata("byte_size", json!(input.byte_size))
    .metadata(
        "content_signature",
        input
            .content_signature
            .map_or(Value::Null, |value| json!(value)),
    )
    .metadata("width", optional_i32(input.width))
    .metadata("height", optional_i32(input.height))
    .metadata("success", json!(input.success));
    if let Some(asset_id) = input.asset_id {
        event = event.metadata("asset_id_prefix", json!(uuid_prefix(asset_id)));
    }
    if let Some(error_kind) = input.error_kind {
        event = event.metadata("error_kind", json!(error_kind));
    }
    if let Some(decoder_error_kind) = input.decoder_error_kind {
        event = event.metadata("decoder_error_kind", json!(decoder_error_kind));
    }
    diagnostics.record(event);
}

/// `profile_media_content_signature` 识别媒体内容签名
/// 核心职责：
/// - 用稳定分类区分声明 MIME 与真实内容
/// - 避免暴露原始字节或图片内容
#[must_use]
pub fn profile_media_content_signature(content: &[u8]) -> &'static str {
    if content.is_empty() {
        return "empty";
    }
    if content.starts_with(&[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A]) {
        return "png";
    }
    if content.starts_with(&[0xFF, 0xD8, 0xFF]) {
        return "jpeg";
    }
    if content.len() >= 12 && content.starts_with(b"RIFF") && &content[8..12] == b"WEBP" {
        return "webp";
    }
    "unknown"
}

#[must_use]
pub const fn profile_error_kind(error: &ProfileError) -> &'static str {
    match error {
        ProfileError::NotFound => "profile.not_found",
        ProfileError::DisplayNameInvalid => "profile.display_name_invalid",
        ProfileError::DisplayNameEditLimitExceeded => "profile.display_name_edit_limit_exceeded",
        ProfileError::BioInvalid => "profile.bio_invalid",
        ProfileError::BioEditLimitExceeded => "profile.bio_edit_limit_exceeded",
        ProfileError::GenderInvalid => "profile.gender_invalid",
        ProfileError::BirthdayInvalid => "profile.birthday_invalid",
        ProfileError::MediaFileRequired => "profile.media_file_required",
        ProfileError::MediaBodyTooLarge => "profile.media_body_too_large",
        ProfileError::MediaMultipartInvalid => "profile.media_multipart_invalid",
        ProfileError::MediaTypeInvalid => "profile.media_type_invalid",
        ProfileError::MediaTooLarge => "profile.media_too_large",
        ProfileError::MediaDecodeFailed => "profile.media_decode_failed",
        ProfileError::Infrastructure(_) => "profile.infrastructure",
    }
}

fn severity(success: bool) -> Severity {
    if success {
        Severity::Info
    } else {
        Severity::Error
    }
}

fn uuid_prefix(value: Uuid) -> String {
    value.to_string().chars().take(8).collect()
}

fn optional_i32(value: Option<i32>) -> Value {
    value.map_or(Value::Null, |value| json!(value))
}
