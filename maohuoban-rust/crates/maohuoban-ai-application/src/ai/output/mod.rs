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
    let scrubbed = scrub_model_output(content);
    let Ok(value) = serde_json::from_str::<serde_json::Value>(scrubbed.trim()) else {
        return scrub_internal_plain_output(&scrubbed);
    };

    value
        .get("answer_text")
        .and_then(serde_json::Value::as_str)
        .map(str::trim)
        .filter(|text| !text.is_empty())
        .map_or_else(String::new, str::to_owned)
}

/// visible_text_prefix_from_model_output 提取可流式展示的用户可见文本前缀
/// 核心职责：
/// - 普通文本直接返回当前完整前缀
/// - JSON Output 只返回 answer_text 字符串值，避免结构化字段泄漏
#[must_use]
pub fn visible_text_prefix_from_model_output(content: &str) -> Option<String> {
    let scrubbed = scrub_model_output_prefix(content);
    let trimmed = scrubbed.trim_start();
    if !(trimmed.starts_with('{') || trimmed.starts_with('[')) {
        return Some(scrub_internal_plain_output(&scrubbed));
    }

    if let Ok(value) = serde_json::from_str::<serde_json::Value>(trimmed) {
        return value
            .get("answer_text")
            .and_then(serde_json::Value::as_str)
            .map(str::trim)
            .filter(|text| !text.is_empty())
            .map(str::to_owned)
            .map(|text| scrub_internal_plain_output(&text));
    }

    extract_json_string_field_prefix(trimmed, "answer_text")
        .map(|text| scrub_internal_plain_output(&text))
        .filter(|text| !text.trim().is_empty())
}

/// scrub_model_output 清理完整模型输出
/// 核心职责：
/// - 删除思考标签中的内部推理
/// - 保留标签外可继续解析的正文或 JSON Output
fn scrub_model_output(content: &str) -> String {
    remove_tagged_internal_sections(content)
}

/// scrub_model_output_prefix 清理流式模型输出前缀
/// 核心职责：
/// - 支持跨 chunk 的思考标签过滤
/// - 避免未闭合内部标签内容提前进入可见正文
fn scrub_model_output_prefix(content: &str) -> String {
    remove_tagged_internal_sections(content)
}

/// remove_tagged_internal_sections 删除内部思考标签片段
/// 核心职责：
/// - 过滤常见 Provider reasoning / scratchpad 标签
/// - 未闭合标签按内部片段处理，等待后续 chunk
fn remove_tagged_internal_sections(content: &str) -> String {
    const TAGS: [&str; 4] = ["think", "thinking", "reasoning", "reasoning_scratchpad"];
    let mut output = content.to_owned();

    for tag in TAGS {
        output = remove_one_tagged_section_kind(&output, tag);
    }

    output
}

fn remove_one_tagged_section_kind(content: &str, tag: &str) -> String {
    let open = format!("<{tag}>");
    let close = format!("</{tag}>");
    let lower = content.to_ascii_lowercase();
    let mut result = String::new();
    let mut cursor = 0;

    while let Some(relative_open) = lower[cursor..].find(&open) {
        let open_start = cursor + relative_open;
        result.push_str(&content[cursor..open_start]);
        let content_after_open = open_start + open.len();

        let Some(relative_close) = lower[content_after_open..].find(&close) else {
            return trim_possible_opening_tag_prefix(&result);
        };
        cursor = content_after_open + relative_close + close.len();
    }

    result.push_str(&content[cursor..]);
    trim_possible_opening_tag_prefix(&result)
}

fn trim_possible_opening_tag_prefix(content: &str) -> String {
    const OPENINGS: [&str; 4] = [
        "<think>",
        "<thinking>",
        "<reasoning>",
        "<reasoning_scratchpad>",
    ];
    let lower = content.to_ascii_lowercase();

    for opening in OPENINGS {
        for prefix_len in 1..opening.len() {
            let prefix = &opening[..prefix_len];
            if lower.ends_with(prefix) {
                let keep_len = content.len() - prefix_len;
                return content[..keep_len].to_owned();
            }
        }
    }

    content.to_owned()
}

/// scrub_internal_plain_output 清理非结构化内部上下文片段
/// 核心职责：
/// - 阻止 memory context、JSON Output 草稿和 Provider 原始结构以正文展示
/// - 对已提取的 answer_text 保持原样返回
fn scrub_internal_plain_output(content: &str) -> String {
    let trimmed = content.trim_start();
    let lower = trimmed.to_ascii_lowercase();
    let blocked_prefixes = [
        "memory_context",
        "memory context",
        "internal facts",
        "internal_fact",
        "json output",
        "provider_raw",
        "provider raw",
    ];

    if blocked_prefixes
        .iter()
        .any(|prefix| lower.starts_with(prefix))
    {
        return String::new();
    }

    content.to_owned()
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn complete_output_does_not_fallback_to_internal_json_without_answer_text() {
        let output = visible_text_from_model_output(
            r#"{"memory_context":{"pet_id":"hidden"},"provider_raw":{"choices":[]}}"#,
        );

        assert_eq!(output, "");
    }

    #[test]
    fn complete_output_does_not_fallback_to_empty_answer_text_json() {
        let output = visible_text_from_model_output(
            r#"{"answer_text":"","provider_raw":{"choices":[]},"internal_facts":["hidden"]}"#,
        );

        assert_eq!(output, "");
    }
}
