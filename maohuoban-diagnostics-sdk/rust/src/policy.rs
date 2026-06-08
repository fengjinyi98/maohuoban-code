/// `PrivacyPolicy` 隐私脱敏策略
/// 核心职责：
/// - 定义需要脱敏的 metadata 字段
/// - 在写入存储前统一处理敏感信息
#[derive(Clone, Debug, Default)]
pub struct PrivacyPolicy {
    keys: BTreeSet<String>,
    query_items: BTreeSet<String>,
    text_patterns: Vec<TextRedactionPattern>,
}

impl PrivacyPolicy {
    /// `redact_key` 添加脱敏字段名
    /// 核心职责：
    /// - 使用大小写不敏感匹配管理敏感字段
    /// - 支持配置时链式声明
    #[must_use]
    pub fn redact_key(mut self, key: impl AsRef<str>) -> Self {
        self.keys.insert(key.as_ref().to_ascii_lowercase());
        self
    }

    /// `redact_query_item` 添加 URL query 脱敏字段
    /// 核心职责：
    /// - 使用大小写不敏感匹配管理敏感 query item
    /// - 支持网络 URL 在落盘前脱敏
    #[must_use]
    pub fn redact_query_item(mut self, item: impl AsRef<str>) -> Self {
        self.query_items.insert(item.as_ref().to_ascii_lowercase());
        self
    }

    /// `redact_text_pattern` 添加文本脱敏规则
    /// 核心职责：
    /// - 支持 message 和 metadata 字符串脱敏
    /// - 复用内置与业务自定义规则
    #[must_use]
    pub fn redact_text_pattern(mut self, pattern: TextRedactionPattern) -> Self {
        self.text_patterns.push(pattern);
        self
    }

    /// `apply` 对事件执行脱敏
    /// 核心职责：
    /// - 保持原事件不可变
    /// - 输出可安全落盘与导出的事件副本
    #[must_use]
    pub fn apply(&self, event: &DiagnosticEvent) -> DiagnosticEvent {
        let mut event = event.clone();
        event.message = self.redact_text(&event.message);
        event.metadata = self.redact_map(&event.metadata);
        event
    }

    fn redact_map(&self, input: &Map<String, Value>) -> Map<String, Value> {
        input
            .iter()
            .map(|(key, value)| {
                let redacted = if self.keys.contains(&key.to_ascii_lowercase()) {
                    Value::String("<redacted>".to_string())
                } else {
                    self.redact_value(value)
                };
                (key.clone(), redacted)
            })
            .collect()
    }

    fn redact_value(&self, value: &Value) -> Value {
        match value {
            Value::String(value) => Value::String(self.redact_text(&self.redact_url_query(value))),
            Value::Object(map) => Value::Object(self.redact_map(map)),
            Value::Array(values) => Value::Array(
                values
                    .iter()
                    .map(|value| self.redact_value(value))
                    .collect(),
            ),
            other => other.clone(),
        }
    }

    fn redact_url_query(&self, value: &str) -> String {
        if self.query_items.is_empty() {
            return value.to_string();
        }
        let Some((base, query)) = value.split_once('?') else {
            return value.to_string();
        };
        let (query, fragment) = query
            .split_once('#')
            .map_or((query, None), |(query, fragment)| (query, Some(fragment)));
        let query = query
            .split('&')
            .map(|item| {
                let (name, _) = item.split_once('=').unwrap_or((item, ""));
                if self.query_items.contains(&name.to_ascii_lowercase()) {
                    format!("{name}=<redacted>")
                } else {
                    item.to_string()
                }
            })
            .collect::<Vec<_>>()
            .join("&");
        match fragment {
            Some(fragment) => format!("{base}?{query}#{fragment}"),
            None => format!("{base}?{query}"),
        }
    }

    fn redact_text(&self, value: &str) -> String {
        self.text_patterns
            .iter()
            .fold(value.to_string(), |output, pattern| pattern.apply(&output))
    }
}

/// `TextRedactionPattern` 文本脱敏模式
/// 核心职责：
/// - 提供常见敏感文本的内置脱敏规则
/// - 支持业务按正则扩展自定义脱敏边界
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum TextRedactionPattern {
    Email,
    PhoneNumber,
    Custom {
        pattern: String,
        replacement: String,
    },
}

impl TextRedactionPattern {
    fn apply(&self, value: &str) -> String {
        match self {
            Self::Email => replace_pattern(
                r"(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}",
                value,
                "<redacted:email>",
            ),
            Self::PhoneNumber => replace_pattern(
                r"(^|[^0-9])(1[3-9][0-9]{9})([^0-9]|$)",
                value,
                "${1}<redacted:phone>${3}",
            ),
            Self::Custom {
                pattern,
                replacement,
            } => replace_pattern(pattern, value, replacement),
        }
    }
}

/// `TrackingConsent` 诊断采集授权状态
/// 核心职责：
/// - 表达宿主服务对诊断采集的授权边界
/// - 让采集策略在统一入口阻断未授权事件写入
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TrackingConsent {
    Granted,
    Pending,
    Denied,
}

/// `CapturePolicy` 采集控制策略
/// 核心职责：
/// - 控制进入存储层的最低事件级别
/// - 裁剪超长 message 和 metadata 字符串，避免诊断数据失控
#[derive(Clone, Debug)]
pub struct CapturePolicy {
    pub enabled: bool,
    pub consent: TrackingConsent,
    pub sample_rate: f64,
    pub minimum_severity: Severity,
    pub max_message_length: usize,
    pub max_metadata_value_length: usize,
}

impl Default for CapturePolicy {
    fn default() -> Self {
        Self {
            enabled: true,
            consent: TrackingConsent::Granted,
            sample_rate: 1.0,
            minimum_severity: Severity::Trace,
            max_message_length: usize::MAX,
            max_metadata_value_length: usize::MAX,
        }
    }
}

impl CapturePolicy {
    /// `apply` 对事件执行采集控制
    /// 核心职责：
    /// - 按启用状态、授权状态和采样率过滤事件
    /// - 过滤低于最低级别的事件
    /// - 输出裁剪后的事件副本供隐私层继续处理
    #[must_use]
    pub fn apply(&self, event: &DiagnosticEvent) -> Option<DiagnosticEvent> {
        if !self.enabled || self.consent != TrackingConsent::Granted || !self.should_sample(event) {
            return None;
        }
        if event.severity.rank() < self.minimum_severity.rank() {
            return None;
        }

        let mut event = event.clone();
        event.message = truncate_string(&event.message, self.max_message_length);
        event.metadata = truncate_map(&event.metadata, self.max_metadata_value_length);
        Some(event)
    }

    fn should_sample(&self, event: &DiagnosticEvent) -> bool {
        if self.sample_rate >= 1.0 {
            return true;
        }
        if self.sample_rate <= 0.0 {
            return false;
        }
        let bytes = event.id.as_bytes();
        let bucket = u16::from_be_bytes([bytes[0], bytes[1]]) % 10_000;
        f64::from(bucket) / 10_000.0 < self.sample_rate
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
use regex::Regex;
use serde_json::{Map, Value};
use std::collections::BTreeSet;

fn replace_pattern(pattern: &str, value: &str, replacement: &str) -> String {
    Regex::new(pattern).map_or_else(
        |_| value.to_string(),
        |regex| regex.replace_all(value, replacement).to_string(),
    )
}
