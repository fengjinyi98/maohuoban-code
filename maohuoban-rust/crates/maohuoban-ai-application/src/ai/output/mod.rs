//! output 模型输出兼容解析
//! 核心职责：
//! - 从厂商 JSON Output 中提取用户可见文本
//! - 在结构化协议扩展前保持现有 delta/final_text 契约稳定

/// visible_text_from_model_output 提取模型输出中的用户可见文本
/// 核心职责：
/// - JSON Output 含 answer_text 时返回该字段
/// - 普通文本或无法解析的 JSON 保持原文输出
#[must_use]
pub fn visible_text_from_model_output(content: &str) -> String {
    let Ok(value) = serde_json::from_str::<serde_json::Value>(content.trim()) else {
        return content.to_owned();
    };

    value
        .get("answer_text")
        .and_then(serde_json::Value::as_str)
        .map(str::trim)
        .filter(|text| !text.is_empty())
        .map_or_else(|| content.to_owned(), str::to_owned)
}

/// visible_text_prefix_from_model_output 提取可流式展示的用户可见文本前缀
/// 核心职责：
/// - 普通文本直接返回当前完整前缀
/// - JSON Output 只返回 answer_text 字符串值，避免结构化字段泄漏
#[must_use]
pub fn visible_text_prefix_from_model_output(content: &str) -> Option<String> {
    let trimmed = content.trim_start();
    if !(trimmed.starts_with('{') || trimmed.starts_with('[')) {
        return Some(content.to_owned());
    }

    if let Ok(value) = serde_json::from_str::<serde_json::Value>(trimmed) {
        return value
            .get("answer_text")
            .and_then(serde_json::Value::as_str)
            .map(str::trim)
            .filter(|text| !text.is_empty())
            .map(str::to_owned);
    }

    extract_json_string_field_prefix(trimmed, "answer_text").filter(|text| !text.trim().is_empty())
}

/// extract_json_string_field_prefix 提取未完成 JSON 字符串字段前缀
/// 核心职责：
/// - 定位指定 JSON 字符串字段
/// - 在 JSON 尚未闭合时返回当前可解码文本前缀
fn extract_json_string_field_prefix(content: &str, field_name: &str) -> Option<String> {
    let needle = format!("\"{field_name}\"");
    let mut search_start = 0;

    while let Some(relative_pos) = content[search_start..].find(&needle) {
        let key_start = search_start + relative_pos;
        let after_key = key_start + needle.len();
        search_start = after_key;

        if key_start > 0 && content.as_bytes().get(key_start - 1) == Some(&b'\\') {
            continue;
        }

        let after_colon = skip_json_whitespace(&content[after_key..]);
        let mut chars = after_colon.chars();
        if chars.next()? != ':' {
            continue;
        }

        let value_start = skip_json_whitespace(chars.as_str());
        let mut value_chars = value_start.chars();
        if value_chars.next()? != '"' {
            return None;
        }

        return Some(decode_json_string_prefix(value_chars.as_str()));
    }

    None
}

/// skip_json_whitespace 跳过 JSON 语法空白
/// 核心职责：
/// - 保持字段定位逻辑只处理 JSON 结构字符
/// - 返回原始输入中的剩余切片
fn skip_json_whitespace(input: &str) -> &str {
    input.trim_start_matches([' ', '\n', '\r', '\t'])
}

/// decode_json_string_prefix 解码 JSON 字符串可用前缀
/// 核心职责：
/// - 支持常见 JSON 转义字符
/// - 在遇到不完整转义时停止输出，等待后续分片
fn decode_json_string_prefix(input: &str) -> String {
    let mut decoded = String::new();
    let mut chars = input.chars();

    while let Some(ch) = chars.next() {
        match ch {
            '"' => break,
            '\\' => match chars.next() {
                Some('"') => decoded.push('"'),
                Some('\\') => decoded.push('\\'),
                Some('/') => decoded.push('/'),
                Some('b') => decoded.push('\u{0008}'),
                Some('f') => decoded.push('\u{000C}'),
                Some('n') => decoded.push('\n'),
                Some('r') => decoded.push('\r'),
                Some('t') => decoded.push('\t'),
                Some('u') => {
                    let Some(ch) = decode_json_unicode_escape(&mut chars) else {
                        break;
                    };
                    decoded.push(ch);
                }
                Some(_) | None => break,
            },
            _ => decoded.push(ch),
        }
    }

    decoded
}

/// decode_json_unicode_escape 解码 JSON Unicode 转义
/// 核心职责：
/// - 消费四位十六进制转义序列
/// - 返回可追加到用户可见文本的字符
fn decode_json_unicode_escape(chars: &mut std::str::Chars<'_>) -> Option<char> {
    let mut value = 0_u32;
    for _ in 0..4 {
        value = (value << 4) + chars.next()?.to_digit(16)?;
    }
    char::from_u32(value)
}
