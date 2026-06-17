use maohuoban_pet_application::pet::{
    BindUploadedPetMediaInput, MediaBindingDiagnostics, MediaUploadDiagnostics,
    record_media_binding, record_media_upload,
};
use maohuoban_pet_domain::pet::MediaAsset;
use uuid::Uuid;

use super::{MediaUploadObjectInput, PreparedMediaObject};

/// record_upload_stage 记录上传仓储成功阶段
/// 核心职责：
/// - 复用 prepared 元数据生成统一上传事件
/// - 保持主上传流程聚焦于持久化编排
pub(super) fn record_upload_stage(
    stage: &'static str,
    input: &MediaUploadObjectInput<'_>,
    prepared: &PreparedMediaObject,
    derivative_count: usize,
) {
    record_media_upload(MediaUploadDiagnostics {
        stage,
        user_id: input.owner_user_id,
        asset_id: Some(prepared.asset_id),
        usage_kind: input.usage_kind,
        mime_type: input.mime_type,
        byte_size: prepared.byte_size,
        width: prepared.width,
        height: prepared.height,
        derivative_count,
        success: true,
        error_kind: None,
    });
}

/// record_upload_failure 记录上传仓储失败阶段
/// 核心职责：
/// - 捕获失败发生的处理阶段
/// - 只暴露错误类别，避免记录底层错误明文
pub(super) fn record_upload_failure(
    input: &MediaUploadObjectInput<'_>,
    asset_id: Option<Uuid>,
    stage: &'static str,
) {
    record_media_upload(MediaUploadDiagnostics {
        stage,
        user_id: input.owner_user_id,
        asset_id,
        usage_kind: input.usage_kind,
        mime_type: input.mime_type,
        byte_size: i64::try_from(input.content.len()).unwrap_or(i64::MAX),
        width: None,
        height: None,
        derivative_count: 0,
        success: false,
        error_kind: Some("infrastructure"),
    });
}

/// record_binding_stage 记录绑定仓储阶段
/// 核心职责：
/// - 复用绑定输入生成 user、pet、asset 关联事件
/// - 在成功路径补充资产用途和展示尺寸
pub(super) fn record_binding_stage(
    stage: &'static str,
    input: &BindUploadedPetMediaInput,
    asset: Option<&MediaAsset>,
    derivative_count: usize,
    success: bool,
) {
    record_media_binding(MediaBindingDiagnostics {
        stage,
        user_id: input.owner_user_id,
        pet_id: input.pet_id,
        asset_id: input.asset_id,
        usage_kind: asset.map(|asset| asset.usage_kind),
        width: asset.and_then(|asset| asset.width),
        height: asset.and_then(|asset| asset.height),
        derivative_count,
        success,
        error_kind: if success {
            None
        } else {
            Some("infrastructure")
        },
    });
}
