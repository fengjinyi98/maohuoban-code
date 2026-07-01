use serde_json::{Map, Value};

const REDACTED: &str = "[redacted]";
const SENSITIVE_MARKERS: &[&str] = &[
    "authorization",
    "api_key",
    "api-key",
    "apikey",
    "bearer",
    "cookie",
];

/// redact_ai_diagnostics_value 脱敏诊断 JSON
/// 核心职责：
/// - 保留开发期可观测正文结构
/// - 移除 Authorization、api_key、Bearer、Cookie 等认证字段和值
#[must_use]
pub fn redact_ai_diagnostics_value(value: &Value) -> Value {
    match value {
        Value::Object(map) => Value::Object(redact_object(map)),
        Value::Array(items) => {
            Value::Array(items.iter().map(redact_ai_diagnostics_value).collect())
        }
        Value::String(text) => Value::String(redact_ai_diagnostics_text(text)),
        Value::Null | Value::Bool(_) | Value::Number(_) => value.clone(),
    }
}

/// redact_ai_diagnostics_text 脱敏诊断正文
/// 核心职责：
/// - 允许记录请求、响应、stream chunk 和模型正文
/// - 清除认证头、API key 字段、Bearer token 和 Cookie 片段
#[must_use]
pub fn redact_ai_diagnostics_text(text: &str) -> String {
    let mut redacted = text.to_owned();
    for marker in SENSITIVE_MARKERS {
        redacted = redact_marker_value(&redacted, marker);
    }
    redacted
}

fn redact_object(map: &Map<String, Value>) -> Map<String, Value> {
    let mut redacted = Map::new();
    for (key, value) in map {
        if contains_sensitive_marker(key) {
            redacted.insert(
                "redacted_sensitive_field".to_owned(),
                Value::String(REDACTED.to_owned()),
            );
        } else {
            redacted.insert(
                redact_ai_diagnostics_text(key),
                redact_ai_diagnostics_value(value),
            );
        }
    }
    redacted
}

fn contains_sensitive_marker(value: &str) -> bool {
    let value = value.to_ascii_lowercase();
    SENSITIVE_MARKERS
        .iter()
        .any(|marker| value.contains(marker))
}

fn redact_marker_value(text: &str, marker: &str) -> String {
    let lower = text.to_ascii_lowercase();
    let marker_lower = marker.to_ascii_lowercase();
    let mut output = String::with_capacity(text.len());
    let mut cursor = 0;

    while let Some(relative_index) = lower[cursor..].find(&marker_lower) {
        let marker_start = cursor + relative_index;
        let marker_end = marker_start + marker.len();
        output.push_str(&text[cursor..marker_start]);
        output.push_str(REDACTED);
        cursor = consume_sensitive_value(text, marker_end, marker);
    }

    output.push_str(&text[cursor..]);
    output
}

fn consume_sensitive_value(text: &str, marker_end: usize, marker: &str) -> usize {
    let mut cursor = marker_end;
    let bytes = text.as_bytes();
    while cursor < bytes.len() && matches!(bytes[cursor], b' ' | b'\t' | b':' | b'=' | b'"' | b'\'')
    {
        cursor += 1;
    }

    if marker.eq_ignore_ascii_case("bearer") {
        while cursor < bytes.len() && !is_bearer_delimiter(bytes[cursor]) {
            cursor += 1;
        }
        return cursor;
    }

    if marker.eq_ignore_ascii_case("authorization")
        || marker.eq_ignore_ascii_case("api_key")
        || marker.eq_ignore_ascii_case("api-key")
        || marker.eq_ignore_ascii_case("apikey")
        || marker.eq_ignore_ascii_case("cookie")
    {
        while cursor < bytes.len() && !is_field_delimiter(bytes[cursor]) {
            cursor += 1;
        }
    }

    cursor
}

fn is_bearer_delimiter(byte: u8) -> bool {
    matches!(
        byte,
        b' ' | b'\t' | b'\r' | b'\n' | b'"' | b'\'' | b',' | b';' | b'}' | b']'
    )
}

fn is_field_delimiter(byte: u8) -> bool {
    matches!(byte, b'\r' | b'\n' | b',' | b';' | b'}' | b']')
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;

    #[test]
    fn redacts_sensitive_keys_and_values_from_json() {
        let value = json!({
            "messages": [{"content": "正文可以保留"}],
            "api_key": "contract-api-key",
            "headers": {
                "Authorization": "Bearer contract-api-key",
                "Cookie": "sid=secret"
            }
        });

        let redacted = redact_ai_diagnostics_value(&value);
        let serialized = serde_json::to_string(&redacted).expect("serialize redacted json");

        assert!(serialized.contains("正文可以保留"));
        assert!(!serialized.contains("api_key"));
        assert!(!serialized.to_ascii_lowercase().contains("authorization"));
        assert!(!serialized.contains("Bearer"));
        assert!(!serialized.contains("Cookie"));
        assert!(!serialized.contains("contract-api-key"));
        assert!(!serialized.contains("sid=secret"));
    }

    #[test]
    fn redacts_sensitive_fragments_from_text() {
        let text = "Authorization: Bearer contract-api-key\nCookie: sid=secret\nbody ok";

        let redacted = redact_ai_diagnostics_text(text);

        assert!(redacted.contains("body ok"));
        assert!(!redacted.to_ascii_lowercase().contains("authorization"));
        assert!(!redacted.contains("Bearer"));
        assert!(!redacted.contains("contract-api-key"));
        assert!(!redacted.contains("Cookie"));
        assert!(!redacted.contains("sid=secret"));
    }
}
