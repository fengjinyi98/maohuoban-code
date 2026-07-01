//! helpers 配置解析辅助函数
//! 核心职责：
//! - 环境变量字符串解析与规范化
//! - 布尔值、Provider 类型、响应格式等通用解析

use serde_json::Value;

/// required_trimmed 读取非空配置值
/// 核心职责：
/// - 将缺失或空白字符串统一视为缺配置
pub(super) fn required_trimmed(value: Option<&str>) -> Option<String> {
    let trimmed = value?.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_owned())
    }
}

/// bool_from_env_value 解析环境变量布尔值
/// 核心职责：
/// - 兼容 true/false、1/0、yes/no、on/off
/// - 无法解析时使用调用方默认值
pub(super) fn bool_from_env_value(value: Option<&str>, default: bool) -> bool {
    match value.map(str::trim).map(str::to_ascii_lowercase).as_deref() {
        Some("true" | "1" | "yes" | "on") => true,
        Some("false" | "0" | "no" | "off") => false,
        _ => default,
    }
}

/// non_empty_or_default 规范化非空字符串
/// 核心职责：
/// - 去除运营配置标识和名称两端空白
/// - 空字符串回落到稳定默认值
pub(super) fn non_empty_or_default(value: &str, default: &str) -> String {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        default.to_owned()
    } else {
        trimmed.to_owned()
    }
}

/// response_format_from_env_value 解析 Provider 默认响应格式
/// 核心职责：
/// - 支持 DeepSeek JSON Output 的 json_object 快捷配置
/// - 保留传入原始 JSON 对象的扩展能力
pub(super) fn response_format_from_env_value(value: Option<&str>) -> Option<Value> {
    let trimmed = value?.trim();
    if trimmed.is_empty() {
        return None;
    }

    match trimmed.to_ascii_lowercase().as_str() {
        "none" | "text" => None,
        "json" | "json_object" => Some(serde_json::json!({ "type": "json_object" })),
        _ => serde_json::from_str::<Value>(trimmed).ok(),
    }
}
