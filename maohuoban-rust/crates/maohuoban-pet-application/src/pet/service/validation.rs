use maohuoban_pet_domain::pet::{PetError, PetResult};

/// validate_text 校验用户输入文案
/// 核心职责：
/// - 拒绝空白关键字段
/// - 输出可映射的领域错误
pub(super) fn validate_text(label: &str, value: &str) -> PetResult<()> {
    if value.trim().is_empty() {
        return Err(PetError::InvalidInput(format!("{label}不能为空")));
    }
    Ok(())
}

/// validate_pet_name 校验宠物名称
/// 核心职责：
/// - 按去除空白后的文字数限制名称长度
/// - 输出稳定的领域错误文案
pub(super) fn validate_pet_name(value: &str) -> PetResult<()> {
    let normalized = normalize_compact_text(value);
    validate_text("宠物名称", &normalized)?;
    if normalized.chars().count() > 6 {
        return Err(PetError::InvalidInput("宠物名称最多 6 个字".to_owned()));
    }
    Ok(())
}

/// normalize_compact_text 去除文本内全部空白字符
/// 核心职责：
/// - 统一宠物名称和品种的写入规范
/// - 让长度校验与最终持久化值保持一致
pub(super) fn normalize_compact_text(value: &str) -> String {
    value
        .chars()
        .filter(|character| !character.is_whitespace())
        .collect()
}

/// normalize_optional_compact_text 规范化可选紧凑文本
/// 核心职责：
/// - 去除文本内全部空白字符
/// - 将空白结果映射为空值，避免持久化无意义文本
pub(super) fn normalize_optional_compact_text(value: Option<String>) -> Option<String> {
    value
        .map(|text| normalize_compact_text(&text))
        .filter(|text| !text.is_empty())
}

pub(super) fn pet_error_kind(error: &PetError) -> &'static str {
    match error {
        PetError::InvalidInput(_) => "invalid_input",
        PetError::NameEditLimitExceeded => "name_edit_limit_exceeded",
        PetError::PetNotFound => "pet_not_found",
        PetError::FoodInventoryNotFound => "food_inventory_not_found",
        PetError::DietAssignmentConflict(_) => "diet_assignment_conflict",
        PetError::DietAssignmentNotFound => "diet_assignment_not_found",
        PetError::Forbidden => "forbidden",
        PetError::Infrastructure(_) => "infrastructure",
    }
}

pub(super) fn validate_optional_microchip(value: Option<&str>) -> PetResult<()> {
    let Some(value) = value else {
        return Ok(());
    };
    let trimmed = value.trim();
    if trimmed.len() != 15 || !trimmed.chars().all(|character| character.is_ascii_digit()) {
        return Err(PetError::InvalidInput(
            "芯片号必须是 15 位纯数字".to_owned(),
        ));
    }
    Ok(())
}

pub(super) fn validate_optional_weight(value: Option<i32>) -> PetResult<()> {
    if value.is_some_and(|weight| weight <= 0) {
        return Err(PetError::InvalidInput("体重必须大于 0".to_owned()));
    }
    Ok(())
}
