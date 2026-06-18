use maohuoban_pet_application::pet::MediaCropMetadata;
use maohuoban_pet_domain::pet::{PetError, PetResult};
use serde_json::Value;

use super::MediaUploadObjectInput;

/// media_object_prefix 生成媒体对象根路径
/// 核心职责：
/// - 已绑定上传进入宠物目录
/// - 建档前上传进入用户 pending 目录
pub(super) fn media_object_prefix(input: &MediaUploadObjectInput<'_>) -> String {
    input.pet_id.map_or_else(
        || format!("pet-media/pending/{}", input.owner_user_id),
        |pet_id| format!("pets/{pet_id}"),
    )
}

/// image_dimensions 读取原始图片尺寸
/// 核心职责：
/// - 为可解码图片资产提供原始宽高
/// - 对非图片媒体保持空尺寸由其他派生链路补齐
pub(super) fn image_dimensions(content: &[u8]) -> PetResult<(Option<i32>, Option<i32>)> {
    let Ok(image) = image::load_from_memory(content) else {
        return Ok((None, None));
    };
    Ok((
        Some(to_i32_dimension(image.width())?),
        Some(to_i32_dimension(image.height())?),
    ))
}

/// crop_display_image 生成展示裁剪图片
/// 核心职责：
/// - 将客户端归一化裁剪区域映射到原图像素区域
/// - 为缩略图和主题色派生提供统一展示输入
pub(super) fn crop_display_image(
    image: &image::DynamicImage,
    crop_metadata: Option<MediaCropMetadata>,
) -> image::DynamicImage {
    let Some(crop_metadata) = crop_metadata else {
        return image.clone();
    };
    let image_width = image.width();
    let image_height = image.height();
    if image_width == 0 || image_height == 0 {
        return image.clone();
    }

    let left = normalized_floor_pixel(crop_metadata.x, image_width);
    let top = normalized_floor_pixel(crop_metadata.y, image_height);
    let right = normalized_ceil_pixel(crop_metadata.x + crop_metadata.width, image_width);
    let bottom = normalized_ceil_pixel(crop_metadata.y + crop_metadata.height, image_height);
    let crop_width = right.saturating_sub(left).max(1);
    let crop_height = bottom.saturating_sub(top).max(1);

    image.crop_imm(left, top, crop_width, crop_height)
}

/// normalized_floor_pixel 转换归一化起点像素
/// 核心职责：
/// - 将裁剪起点稳定落到像素网格
/// - 保护坐标不越过图片边界
fn normalized_floor_pixel(value: f64, dimension: u32) -> u32 {
    #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
    ((value.clamp(0.0, 1.0) * f64::from(dimension)).floor() as u32).min(dimension - 1)
}

/// normalized_ceil_pixel 转换归一化终点像素
/// 核心职责：
/// - 将裁剪终点稳定覆盖用户选择区域
/// - 保护终点不越过图片边界
fn normalized_ceil_pixel(value: f64, dimension: u32) -> u32 {
    #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
    ((value.clamp(0.0, 1.0) * f64::from(dimension)).ceil() as u32).clamp(1, dimension)
}

/// media_derivative_metadata 合并媒体派生元数据
/// 核心职责：
/// - 保留派生物原有 metadata 字段
/// - 在存在裁剪信息时持久化展示裁剪区域
pub(super) fn media_derivative_metadata(
    mut metadata: Value,
    crop_metadata: Option<Value>,
) -> Value {
    if let Some(crop_metadata) = crop_metadata
        && let Some(object) = metadata.as_object_mut()
    {
        object.insert("crop".to_owned(), crop_metadata);
    }
    metadata
}

/// crop_metadata_json 序列化裁剪元数据
/// 核心职责：
/// - 固定派生 metadata 中裁剪区域字段名
/// - 保持与 HTTP multipart 字段语义一致
pub(super) fn crop_metadata_json(crop_metadata: MediaCropMetadata) -> Value {
    serde_json::json!({
        "x": crop_metadata.x,
        "y": crop_metadata.y,
        "width": crop_metadata.width,
        "height": crop_metadata.height
    })
}

/// metadata_i32 读取派生元数据尺寸
/// 核心职责：
/// - 从 JSON metadata 中提取可写入资产表的整数尺寸
/// - 对缺失字段保持空值兼容
pub(super) fn metadata_i32(metadata: &Value, key: &str) -> PetResult<Option<i32>> {
    let Some(value) = metadata.get(key).and_then(serde_json::Value::as_u64) else {
        return Ok(None);
    };
    i32::try_from(value)
        .map(Some)
        .map_err(|_| PetError::InvalidInput("媒体尺寸过大".to_owned()))
}

/// to_i32_dimension 转换媒体尺寸
/// 核心职责：
/// - 保护数据库 integer 字段边界
/// - 统一尺寸溢出的错误语义
pub(super) fn to_i32_dimension(value: u32) -> PetResult<i32> {
    i32::try_from(value).map_err(|_| PetError::InvalidInput("媒体尺寸过大".to_owned()))
}
