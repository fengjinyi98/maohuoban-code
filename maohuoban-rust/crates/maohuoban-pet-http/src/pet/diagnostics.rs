use maohuoban_pet_application::pet::{
    BindUploadedPetMediaInput, MediaBindingDiagnostics, MediaUploadDiagnostics,
    PendingPetMediaUploadInput, PetProfileDiagnostics, record_media_binding, record_media_upload,
    record_pet_profile,
};
use maohuoban_pet_domain::pet::{PetMediaUploadResult, PetProfile};
use uuid::Uuid;

/// record_profile_http 记录宠物档案 HTTP 边界
/// 核心职责：
/// - 捕获请求和响应阶段的 breed 字段状态
/// - 保持 router 只负责请求编排和响应返回
pub(super) fn record_profile_http(
    stage: &'static str,
    action: &'static str,
    user_id: Uuid,
    pet_id: Option<Uuid>,
    breed: Option<&str>,
    success: bool,
) {
    record_pet_profile(PetProfileDiagnostics {
        stage,
        action,
        user_id,
        pet_id,
        breed,
        success,
    });
}

/// record_profile_http_response 记录档案响应模型
/// 核心职责：
/// - 从领域模型读取脱敏观测字段
/// - 统一 create 和 update 响应事件
pub(super) fn record_profile_http_response(
    action: &'static str,
    user_id: Uuid,
    profile: &PetProfile,
) {
    record_profile_http(
        "http.response",
        action,
        user_id,
        Some(profile.id),
        profile.breed.as_deref(),
        true,
    );
}

/// record_upload_http_request 记录媒体上传请求
/// 核心职责：
/// - 捕获上传用途、mime 和字节大小
/// - 避免记录文件名、对象 key 和用户原始内容
pub(super) fn record_upload_http_request(input: &PendingPetMediaUploadInput) {
    record_media_upload(MediaUploadDiagnostics {
        stage: "http.request",
        user_id: input.owner_user_id,
        asset_id: None,
        usage_kind: input.usage_kind,
        mime_type: &input.mime_type,
        byte_size: i64::try_from(input.content.len()).unwrap_or(i64::MAX),
        width: None,
        height: None,
        derivative_count: 0,
        success: true,
        error_kind: None,
    });
}

/// record_upload_http_response 记录媒体上传响应
/// 核心职责：
/// - 捕获后端返回给前端的资产尺寸和派生数量
/// - 关联上传用户与媒体资产脱敏标识
pub(super) fn record_upload_http_response(user_id: Uuid, upload: &PetMediaUploadResult) {
    record_media_upload(MediaUploadDiagnostics {
        stage: "http.response",
        user_id,
        asset_id: Some(upload.asset.id),
        usage_kind: upload.asset.usage_kind,
        mime_type: &upload.asset.mime_type,
        byte_size: upload.asset.byte_size,
        width: upload.asset.width,
        height: upload.asset.height,
        derivative_count: upload.derivatives.len(),
        success: true,
        error_kind: None,
    });
}

/// record_binding_http_request 记录媒体绑定请求
/// 核心职责：
/// - 捕获宠物和待绑定资产的脱敏关联
/// - 在读取资产前允许 usage kind 为空
pub(super) fn record_binding_http_request(input: &BindUploadedPetMediaInput) {
    record_media_binding(MediaBindingDiagnostics {
        stage: "http.request",
        user_id: input.owner_user_id,
        pet_id: input.pet_id,
        asset_id: input.asset_id,
        usage_kind: None,
        width: None,
        height: None,
        derivative_count: 0,
        success: true,
        error_kind: None,
    });
}

/// record_binding_http_response 记录媒体绑定响应
/// 核心职责：
/// - 捕获绑定后真正生效的媒体用途和尺寸
/// - 让首页 hero 输出能与绑定接口按 asset 对齐
pub(super) fn record_binding_http_response(
    user_id: Uuid,
    pet_id: Uuid,
    upload: &PetMediaUploadResult,
) {
    record_media_binding(MediaBindingDiagnostics {
        stage: "http.response",
        user_id,
        pet_id,
        asset_id: upload.asset.id,
        usage_kind: Some(upload.asset.usage_kind),
        width: upload.asset.width,
        height: upload.asset.height,
        derivative_count: upload.derivatives.len(),
        success: true,
        error_kind: None,
    });
}
