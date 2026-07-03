use std::collections::BTreeMap;
use std::path::PathBuf;

use super::shared::{ChangeKind, TouchedPath};

/// extract_touched_paths 提取本次工具触碰路径
/// 核心职责：
/// - 支持 Write/Edit 类事件的 file_path 字段
/// - 支持 apply_patch 文本中的文件路径
#[cfg(test)]
pub(crate) fn extract_touched_paths(input: &str) -> Vec<PathBuf> {
    extract_touched_files(input)
        .into_iter()
        .map(|touched_path| touched_path.path)
        .collect()
}

/// extract_touched_files 提取本次工具触碰文件
/// 核心职责：
/// - 识别 apply_patch 的新增、更新和删除
/// - 为 Write/Edit 类事件补充保守变更类型
pub(crate) fn extract_touched_files(input: &str) -> Vec<TouchedPath> {
    let mut paths = BTreeMap::new();
    let tool_name = values_after_json_key(input, "tool_name")
        .into_iter()
        .next()
        .unwrap_or_default();
    let file_path_kind = match tool_name.as_str() {
        "Write" => ChangeKind::Added,
        "Edit" | "MultiEdit" => ChangeKind::Updated,
        _ => ChangeKind::Updated,
    };

    for value in values_after_json_key(input, "file_path") {
        insert_touched_path(&mut paths, PathBuf::from(value), file_path_kind);
    }

    for line in decoded_json_text(input).lines() {
        for (marker, kind) in [
            ("*** Add File: ", ChangeKind::Added),
            ("*** Update File: ", ChangeKind::Updated),
            ("*** Delete File: ", ChangeKind::Deleted),
            ("*** Move to: ", ChangeKind::Updated),
        ] {
            if let Some(path) = line.strip_prefix(marker) {
                let trimmed = path.trim();
                if !trimmed.is_empty() {
                    insert_touched_path(&mut paths, PathBuf::from(trimmed), kind);
                }
            }
        }
    }

    paths
        .into_iter()
        .map(|(path, kind)| TouchedPath { path, kind })
        .collect()
}

/// insert_touched_path 合并触碰文件记录
/// 核心职责：
/// - 保持路径去重
/// - 新增文件语义优先于更新语义
fn insert_touched_path(paths: &mut BTreeMap<PathBuf, ChangeKind>, path: PathBuf, kind: ChangeKind) {
    paths
        .entry(path)
        .and_modify(|existing| {
            if kind == ChangeKind::Added {
                *existing = kind;
            }
        })
        .or_insert(kind);
}

/// values_after_json_key 提取简单 JSON 字符串字段
/// 核心职责：
/// - 在无外部依赖条件下读取 hook 输入路径
/// - 支持常见转义字符
fn values_after_json_key(input: &str, key: &str) -> Vec<String> {
    let mut result = Vec::new();
    let pattern = format!("\"{key}\"");
    let mut offset = 0;
    while let Some(position) = input[offset..].find(&pattern) {
        let start = offset + position + pattern.len();
        let Some(colon) = input[start..].find(':') else {
            break;
        };
        let mut cursor = start + colon + 1;
        while input
            .as_bytes()
            .get(cursor)
            .is_some_and(u8::is_ascii_whitespace)
        {
            cursor += 1;
        }
        if input.as_bytes().get(cursor) == Some(&b'"') {
            if let Some((value, consumed)) = parse_json_string(&input[cursor..]) {
                result.push(value);
                offset = cursor + consumed;
                continue;
            }
        }
        offset = cursor.saturating_add(1);
    }
    result
}

/// decoded_json_text 解码 JSON 文本片段
/// 核心职责：
/// - 将 hook 输入中的换行转义还原
/// - 让 apply_patch 路径可以按行解析
fn decoded_json_text(input: &str) -> String {
    input
        .replace("\\n", "\n")
        .replace("\\\"", "\"")
        .replace("\\\\", "\\")
}

/// parse_json_string 解析 JSON 字符串
/// 核心职责：
/// - 解析双引号字符串内容
/// - 返回已消费字节数
fn parse_json_string(input: &str) -> Option<(String, usize)> {
    if !input.starts_with('"') {
        return None;
    }
    let mut output = String::new();
    let mut escaped = false;
    for (index, ch) in input.char_indices().skip(1) {
        if escaped {
            match ch {
                'n' => output.push('\n'),
                't' => output.push('\t'),
                'r' => output.push('\r'),
                '"' => output.push('"'),
                '\\' => output.push('\\'),
                other => output.push(other),
            }
            escaped = false;
            continue;
        }
        match ch {
            '\\' => escaped = true,
            '"' => return Some((output, index + 1)),
            other => output.push(other),
        }
    }
    None
}
