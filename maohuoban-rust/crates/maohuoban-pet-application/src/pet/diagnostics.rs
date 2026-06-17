use maohuoban_diagnostics::{DiagnosticEvent, Diagnostics, EventKind, Severity};
use maohuoban_pet_domain::pet::MediaUsageKind;
use serde_json::{Value, json};
use uuid::Uuid;

/// PetProfileDiagnostics 宠物档案观测输入
/// 核心职责：
/// - 描述档案创建和更新链路中的字段状态
/// - 记录脱敏后的品种字段传递结果
#[derive(Clone, Copy)]
pub struct PetProfileDiagnostics<'a> {
    pub stage: &'a str,
    pub action: &'a str,
    pub user_id: Uuid,
    pub pet_id: Option<Uuid>,
    pub breed: Option<&'a str>,
    pub success: bool,
}

/// MediaUploadDiagnostics 媒体上传观测输入
/// 核心职责：
/// - 描述上传链路中的资产元数据和处理状态
/// - 统一图片、视频和派生物的脱敏观测字段
#[derive(Clone, Copy)]
pub struct MediaUploadDiagnostics<'a> {
    pub stage: &'a str,
    pub user_id: Uuid,
    pub asset_id: Option<Uuid>,
    pub usage_kind: MediaUsageKind,
    pub mime_type: &'a str,
    pub byte_size: i64,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub derivative_count: usize,
    pub success: bool,
    pub error_kind: Option<&'a str>,
}

/// MediaBindingDiagnostics 媒体绑定观测输入
/// 核心职责：
/// - 描述 pending 资产绑定到宠物的结果
/// - 让媒体写入和首页展示可以按 asset 追踪
#[derive(Clone, Copy)]
pub struct MediaBindingDiagnostics<'a> {
    pub stage: &'a str,
    pub user_id: Uuid,
    pub pet_id: Uuid,
    pub asset_id: Uuid,
    pub usage_kind: Option<MediaUsageKind>,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub derivative_count: usize,
    pub success: bool,
    pub error_kind: Option<&'a str>,
}

/// HomeDashboardDiagnosticSnapshot 首页聚合观测输入
/// 核心职责：
/// - 描述首页选择宠物和 hero 媒体输出契约
/// - 保留前端消费所需媒体类型、尺寸和主题色状态
#[derive(Clone, Copy)]
pub struct HomeDashboardDiagnosticSnapshot<'a> {
    pub stage: &'a str,
    pub user_id: Option<Uuid>,
    pub selected_pet_id: Option<Uuid>,
    pub pet_count: usize,
    pub background_asset_id: Option<Uuid>,
    pub background_media_kind: Option<&'a str>,
    pub metadata_present: bool,
    pub hero_image_present: bool,
    pub hero_video_present: bool,
    pub hero_video_width: Option<i32>,
    pub hero_video_height: Option<i32>,
    pub hero_theme_color_hex: Option<&'a str>,
}

/// record_pet_profile 记录宠物档案字段链路
/// 核心职责：
/// - 捕获 HTTP、应用服务和仓储边界的 breed 状态
/// - 避免写入用户真实输入文本
pub fn record_pet_profile(input: PetProfileDiagnostics<'_>) {
    let Some(diagnostics) = Diagnostics::current() else {
        return;
    };
    let mut event = DiagnosticEvent::new(
        EventKind::Analytics,
        severity(input.success),
        format!("pet.profile.{}.{}", input.action, input.stage),
    )
    .metadata("stage", json!(input.stage))
    .metadata("action", json!(input.action))
    .metadata("user_id_prefix", json!(uuid_prefix(input.user_id)))
    .metadata("breed_present", json!(input.breed.is_some()))
    .metadata(
        "breed_length_non_whitespace",
        json!(text_length_non_whitespace(input.breed)),
    )
    .metadata("success", json!(input.success));
    if let Some(pet_id) = input.pet_id {
        event = event.metadata("pet_id_prefix", json!(uuid_prefix(pet_id)));
    }
    diagnostics.record(event);
}

/// record_media_upload 记录媒体上传链路
/// 核心职责：
/// - 捕获上传、对象准备、尺寸解析和数据库写入状态
/// - 统一图片和视频媒体资产的尺寸观测字段
pub fn record_media_upload(input: MediaUploadDiagnostics<'_>) {
    let Some(diagnostics) = Diagnostics::current() else {
        return;
    };
    let mut event = DiagnosticEvent::new(
        EventKind::Analytics,
        severity(input.success),
        format!("pet.media.upload.{}", input.stage),
    )
    .metadata("stage", json!(input.stage))
    .metadata("user_id_prefix", json!(uuid_prefix(input.user_id)))
    .metadata("usage_kind", json!(input.usage_kind.as_str()))
    .metadata("mime_type", json!(input.mime_type))
    .metadata("byte_size", json!(input.byte_size))
    .metadata("width", optional_i32(input.width))
    .metadata("height", optional_i32(input.height))
    .metadata("derivative_count", json!(input.derivative_count))
    .metadata("success", json!(input.success));
    if let Some(asset_id) = input.asset_id {
        event = event.metadata("asset_id_prefix", json!(uuid_prefix(asset_id)));
    }
    if let Some(error_kind) = input.error_kind {
        event = event.metadata("error_kind", json!(error_kind));
    }
    diagnostics.record(event);
}

/// record_media_binding 记录媒体绑定链路
/// 核心职责：
/// - 捕获资产绑定到宠物后的业务状态
/// - 关联 user、pet、asset 三个主体的脱敏标识
pub fn record_media_binding(input: MediaBindingDiagnostics<'_>) {
    let Some(diagnostics) = Diagnostics::current() else {
        return;
    };
    let mut event = DiagnosticEvent::new(
        EventKind::Analytics,
        severity(input.success),
        format!("pet.media.binding.{}", input.stage),
    )
    .metadata("stage", json!(input.stage))
    .metadata("user_id_prefix", json!(uuid_prefix(input.user_id)))
    .metadata("pet_id_prefix", json!(uuid_prefix(input.pet_id)))
    .metadata("asset_id_prefix", json!(uuid_prefix(input.asset_id)))
    .metadata(
        "usage_kind",
        input
            .usage_kind
            .map_or(Value::Null, |usage_kind| json!(usage_kind.as_str())),
    )
    .metadata("width", optional_i32(input.width))
    .metadata("height", optional_i32(input.height))
    .metadata("derivative_count", json!(input.derivative_count))
    .metadata("success", json!(input.success));
    if let Some(error_kind) = input.error_kind {
        event = event.metadata("error_kind", json!(error_kind));
    }
    diagnostics.record(event);
}

/// record_home_dashboard_snapshot 记录首页聚合输出链路
/// 核心职责：
/// - 捕获首页 selected pet 和 hero 媒体 DTO 状态
/// - 让后端输出与 iOS 渲染链路可以按同一 asset 排查
pub fn record_home_dashboard_snapshot(input: HomeDashboardDiagnosticSnapshot<'_>) {
    let Some(diagnostics) = Diagnostics::current() else {
        return;
    };
    let mut event = DiagnosticEvent::new(
        EventKind::Analytics,
        Severity::Info,
        format!("home.dashboard.{}", input.stage),
    )
    .metadata("stage", json!(input.stage))
    .metadata("pet_count", json!(input.pet_count))
    .metadata("metadata_present", json!(input.metadata_present))
    .metadata("hero_image_present", json!(input.hero_image_present))
    .metadata("hero_video_present", json!(input.hero_video_present))
    .metadata("hero_video_width", optional_i32(input.hero_video_width))
    .metadata("hero_video_height", optional_i32(input.hero_video_height))
    .metadata(
        "hero_theme_color_present",
        json!(input.hero_theme_color_hex.is_some()),
    );
    if let Some(user_id) = input.user_id {
        event = event.metadata("user_id_prefix", json!(uuid_prefix(user_id)));
    }
    if let Some(selected_pet_id) = input.selected_pet_id {
        event = event.metadata(
            "selected_pet_id_prefix",
            json!(uuid_prefix(selected_pet_id)),
        );
    }
    if let Some(background_asset_id) = input.background_asset_id {
        event = event.metadata(
            "background_asset_id_prefix",
            json!(uuid_prefix(background_asset_id)),
        );
    }
    if let Some(background_media_kind) = input.background_media_kind {
        event = event.metadata("background_media_kind", json!(background_media_kind));
    }
    if let Some(hero_theme_color_hex) = input.hero_theme_color_hex {
        event = event.metadata("hero_theme_color_hex", json!(hero_theme_color_hex));
    }
    diagnostics.record(event);
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

fn text_length_non_whitespace(value: Option<&str>) -> usize {
    value.map_or(0, |text| {
        text.chars()
            .filter(|character| !character.is_whitespace())
            .count()
    })
}

fn optional_i32(value: Option<i32>) -> Value {
    value.map_or(Value::Null, |value| json!(value))
}
