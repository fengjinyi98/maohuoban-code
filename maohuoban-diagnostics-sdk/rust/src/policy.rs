/// `PrivacyPolicy` 隐私脱敏策略
/// 核心职责：
/// - 定义需要脱敏的 metadata 字段
/// - 在写入存储前统一处理敏感信息
#[derive(Clone, Debug, Default)]
pub struct PrivacyPolicy {
    redacted_keys: BTreeSet<String>,
}

impl PrivacyPolicy {
    /// `redact_key` 添加脱敏字段名
    /// 核心职责：
    /// - 使用大小写不敏感匹配管理敏感字段
    /// - 支持配置时链式声明
    #[must_use]
    pub fn redact_key(mut self, key: impl AsRef<str>) -> Self {
        self.redacted_keys.insert(key.as_ref().to_ascii_lowercase());
        self
    }

    /// `apply` 对事件执行脱敏
    /// 核心职责：
    /// - 保持原事件不可变
    /// - 输出可安全落盘与导出的事件副本
    #[must_use]
    pub fn apply(&self, event: &DiagnosticEvent) -> DiagnosticEvent {
        let mut event = event.clone();
        event.metadata = redact_map(&event.metadata, &self.redacted_keys);
        event
    }
}

/// `CapturePolicy` 采集控制策略
/// 核心职责：
/// - 控制进入存储层的最低事件级别
/// - 裁剪超长 message 和 metadata 字符串，避免诊断数据失控
#[derive(Clone, Debug)]
pub struct CapturePolicy {
    pub minimum_severity: Severity,
    pub max_message_length: usize,
    pub max_metadata_value_length: usize,
}

impl Default for CapturePolicy {
    fn default() -> Self {
        Self {
            minimum_severity: Severity::Trace,
            max_message_length: usize::MAX,
            max_metadata_value_length: usize::MAX,
        }
    }
}

impl CapturePolicy {
    /// `apply` 对事件执行采集控制
    /// 核心职责：
    /// - 过滤低于最低级别的事件
    /// - 输出裁剪后的事件副本供隐私层继续处理
    #[must_use]
    pub fn apply(&self, event: &DiagnosticEvent) -> Option<DiagnosticEvent> {
        if event.severity.rank() < self.minimum_severity.rank() {
            return None;
        }

        let mut event = event.clone();
        event.message = truncate_string(&event.message, self.max_message_length);
        event.metadata = truncate_map(&event.metadata, self.max_metadata_value_length);
        Some(event)
    }
}

fn redact_map(input: &Map<String, Value>, keys: &BTreeSet<String>) -> Map<String, Value> {
    input
        .iter()
        .map(|(key, value)| {
            let redacted = if keys.contains(&key.to_ascii_lowercase()) {
                Value::String("<redacted>".to_string())
            } else {
                redact_value(value, keys)
            };
            (key.clone(), redacted)
        })
        .collect()
}

fn redact_value(value: &Value, keys: &BTreeSet<String>) -> Value {
    match value {
        Value::Object(map) => Value::Object(redact_map(map, keys)),
        Value::Array(values) => Value::Array(
            values
                .iter()
                .map(|value| redact_value(value, keys))
                .collect(),
        ),
        other => other.clone(),
    }
}

fn truncate_map(input: &Map<String, Value>, limit: usize) -> Map<String, Value> {
    input
        .iter()
        .map(|(key, value)| (key.clone(), truncate_value(value, limit)))
        .collect()
}

fn truncate_value(value: &Value, limit: usize) -> Value {
    match value {
        Value::String(value) => Value::String(truncate_string(value, limit)),
        Value::Object(map) => Value::Object(truncate_map(map, limit)),
        Value::Array(values) => Value::Array(
            values
                .iter()
                .map(|value| truncate_value(value, limit))
                .collect(),
        ),
        other => other.clone(),
    }
}

fn truncate_string(value: &str, limit: usize) -> String {
    if value.chars().count() <= limit {
        return value.to_string();
    }
    value.chars().take(limit).collect::<String>() + "..."
}
use crate::{DiagnosticEvent, Severity};
use serde_json::{Map, Value};
use std::collections::BTreeSet;
