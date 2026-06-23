use maohuoban_profile_application::profile::{
    ProfileMediaKind, ProfileMediaUploadDiagnostics, UploadProfileMediaInput, profile_error_kind,
    profile_media_content_signature, record_profile_media_upload,
};
use maohuoban_profile_domain::profile::{ProfileError, ProfileMediaAsset, UserProfile};
use uuid::Uuid;

/// `ProfileMediaHttpUploadContext` 用户资料媒体 HTTP 观测上下文
/// 核心职责：
/// - 在请求输入被移动到应用服务前保存脱敏上传上下文
/// - 为 HTTP 响应阶段补齐相同媒体上下文字段
pub(super) struct ProfileMediaHttpUploadContext {
    user_id: Uuid,
    kind: ProfileMediaKind,
    declared_mime_type: String,
    byte_size: i64,
    content_signature: &'static str,
}

impl ProfileMediaHttpUploadContext {
    pub(super) fn from_input(input: &UploadProfileMediaInput) -> Self {
        Self {
            user_id: input.user_id,
            kind: input.kind,
            declared_mime_type: input.mime_type.clone(),
            byte_size: i64::try_from(input.content.len()).unwrap_or(i64::MAX),
            content_signature: profile_media_content_signature(&input.content),
        }
    }
}

/// `record_profile_media_http_request` 记录用户资料媒体 HTTP 请求
/// 核心职责：
/// - 捕获 multipart 解包后的媒体声明与内容签名
/// - 避免记录文件名和图片原始内容
pub(super) fn record_profile_media_http_request(context: &ProfileMediaHttpUploadContext) {
    record_profile_media_upload(ProfileMediaUploadDiagnostics {
        stage: "http.request",
        user_id: context.user_id,
        asset_id: None,
        kind: context.kind,
        declared_mime_type: &context.declared_mime_type,
        byte_size: context.byte_size,
        content_signature: Some(context.content_signature),
        width: None,
        height: None,
        success: true,
        error_kind: None,
        decoder_error_kind: None,
    });
}

/// `record_profile_media_http_parse_failure` 记录 multipart 解析失败
/// 核心职责：
/// - 在文件字段缺失或 multipart 读取失败时留下业务错误码
/// - 关联当前用户和资料媒体类型
pub(super) fn record_profile_media_http_parse_failure(
    user_id: Uuid,
    kind: ProfileMediaKind,
    error: &ProfileError,
) {
    record_profile_media_upload(ProfileMediaUploadDiagnostics {
        stage: "http.request",
        user_id,
        asset_id: None,
        kind,
        declared_mime_type: "",
        byte_size: 0,
        content_signature: None,
        width: None,
        height: None,
        success: false,
        error_kind: Some(profile_error_kind(error)),
        decoder_error_kind: None,
    });
}

/// `record_profile_media_http_response` 记录用户资料媒体 HTTP 响应
/// 核心职责：
/// - 成功时补齐返回给前端的资产和尺寸
/// - 失败时记录最终业务错误码
pub(super) fn record_profile_media_http_response(
    context: &ProfileMediaHttpUploadContext,
    result: Result<&UserProfile, &ProfileError>,
) {
    match result {
        Ok(profile) => {
            let media = selected_media(profile, context.kind);
            record_profile_media_upload(ProfileMediaUploadDiagnostics {
                stage: "http.response",
                user_id: context.user_id,
                asset_id: media.map(|media| media.asset_id),
                kind: context.kind,
                declared_mime_type: media.map_or(context.declared_mime_type.as_str(), |media| {
                    media.mime_type.as_str()
                }),
                byte_size: context.byte_size,
                content_signature: Some(context.content_signature),
                width: media.and_then(|media| media.width),
                height: media.and_then(|media| media.height),
                success: true,
                error_kind: None,
                decoder_error_kind: None,
            });
        }
        Err(error) => record_profile_media_upload(ProfileMediaUploadDiagnostics {
            stage: "http.response",
            user_id: context.user_id,
            asset_id: None,
            kind: context.kind,
            declared_mime_type: &context.declared_mime_type,
            byte_size: context.byte_size,
            content_signature: Some(context.content_signature),
            width: None,
            height: None,
            success: false,
            error_kind: Some(profile_error_kind(error)),
            decoder_error_kind: None,
        }),
    }
}

fn selected_media(profile: &UserProfile, kind: ProfileMediaKind) -> Option<&ProfileMediaAsset> {
    match kind {
        ProfileMediaKind::Avatar => profile.avatar.as_ref(),
        ProfileMediaKind::Cover => profile.cover.as_ref(),
    }
}
