use std::collections::HashMap;

use maohuoban_home_domain::home::PetHeroSummary;
use maohuoban_pet_application::pet::{
    HomeDashboardDiagnosticSnapshot, MediaAssetDisplayMetadata, record_home_dashboard_snapshot,
};
use maohuoban_pet_domain::pet::{PetBackgroundMediaKind, PetProfile};
use uuid::Uuid;

/// record_home_pet_list 记录首页宠物列表读取结果
/// 核心职责：
/// - 捕获用户上下文下可见宠物数量
/// - 保留当前选择宠物参数的脱敏标识
pub(super) fn record_home_pet_list(user_id: Uuid, selected_pet_id: Option<Uuid>, pet_count: usize) {
    record_home_dashboard_snapshot(HomeDashboardDiagnosticSnapshot {
        stage: "provider.list_pets",
        user_id: Some(user_id),
        selected_pet_id,
        pet_count,
        background_asset_id: None,
        background_media_kind: None,
        metadata_present: false,
        hero_image_present: false,
        hero_video_present: false,
        hero_video_width: None,
        hero_video_height: None,
        hero_theme_color_hex: None,
    });
}

/// record_home_empty_state 记录首页空态输出
/// 核心职责：
/// - 标记后端已进入无宠物空态
/// - 为前端误显示添加宠物页提供后端证据
pub(super) fn record_home_empty_state(user_id: Uuid) {
    record_home_dashboard_snapshot(HomeDashboardDiagnosticSnapshot {
        stage: "provider.empty_state",
        user_id: Some(user_id),
        selected_pet_id: None,
        pet_count: 0,
        background_asset_id: None,
        background_media_kind: None,
        metadata_present: false,
        hero_image_present: false,
        hero_video_present: false,
        hero_video_width: None,
        hero_video_height: None,
        hero_theme_color_hex: None,
    });
}

/// record_home_media_metadata 记录首页媒体元数据读取结果
/// 核心职责：
/// - 捕获选中宠物背景资产是否读取到展示元数据
/// - 保留背景媒体类型用于图片和视频分支排查
pub(super) fn record_home_media_metadata(
    user_id: Uuid,
    selected_pet: &PetProfile,
    pet_count: usize,
    media_metadata: &HashMap<Uuid, MediaAssetDisplayMetadata>,
) {
    record_home_dashboard_snapshot(HomeDashboardDiagnosticSnapshot {
        stage: "provider.media_metadata",
        user_id: Some(user_id),
        selected_pet_id: Some(selected_pet.id),
        pet_count,
        background_asset_id: selected_pet.background_asset_id,
        background_media_kind: selected_pet
            .background_media_kind
            .map(PetBackgroundMediaKind::as_str),
        metadata_present: has_background_metadata(selected_pet, media_metadata),
        hero_image_present: false,
        hero_video_present: false,
        hero_video_width: None,
        hero_video_height: None,
        hero_theme_color_hex: None,
    });
}

/// record_home_selected_pet_output 记录首页选中宠物 DTO 输出
/// 核心职责：
/// - 捕获 hero 图片或视频最终输出状态
/// - 记录前端布局消费的尺寸和主题色字段
pub(super) fn record_home_selected_pet_output(
    user_id: Uuid,
    selected_pet: &PetProfile,
    selected_summary: &PetHeroSummary,
    pet_count: usize,
    media_metadata: &HashMap<Uuid, MediaAssetDisplayMetadata>,
) {
    record_home_dashboard_snapshot(HomeDashboardDiagnosticSnapshot {
        stage: "selected_pet.output",
        user_id: Some(user_id),
        selected_pet_id: Some(selected_summary.id),
        pet_count,
        background_asset_id: selected_pet.background_asset_id,
        background_media_kind: selected_pet
            .background_media_kind
            .map(PetBackgroundMediaKind::as_str),
        metadata_present: has_background_metadata(selected_pet, media_metadata),
        hero_image_present: selected_summary.hero_image_url.is_some(),
        hero_video_present: selected_summary.hero_video_url.is_some(),
        hero_video_width: selected_summary.hero_video_width,
        hero_video_height: selected_summary.hero_video_height,
        hero_theme_color_hex: selected_summary.hero_theme_color_hex.as_deref(),
    });
}

fn has_background_metadata(
    selected_pet: &PetProfile,
    media_metadata: &HashMap<Uuid, MediaAssetDisplayMetadata>,
) -> bool {
    selected_pet
        .background_asset_id
        .is_some_and(|asset_id| media_metadata.contains_key(&asset_id))
}
