use std::collections::BTreeSet;
use std::fs;
use std::io::{self, Read};
use std::path::{Path, PathBuf};

const ERROR_CODE: &str = "CODEX_PROJECT_STRUCTURE_HOOK";
const SWIFT_GUIDELINE_LIMIT: usize = 250;
const SWIFT_HARD_LIMIT: usize = 400;
const RUST_GUIDELINE_LIMIT: usize = 300;
const RUST_HARD_LIMIT: usize = 500;
const RESPONSIBILITY_DIRS: &[&str] = &[
    "Domain",
    "Data",
    "Presentation",
    "Stores",
    "Services",
    "Infrastructure",
    "Theme",
];

/// Finding 项目结构检查结果
/// 核心职责：
/// - 表达单个文件触发的结构规则
/// - 区分提示项和阻断项
#[derive(Debug, Clone, PartialEq, Eq)]
struct Finding {
    path: String,
    rule: &'static str,
    severity: Severity,
    message: String,
}

/// Severity 检查结果严重程度
/// 核心职责：
/// - 标记可继续的建议项
/// - 标记需要阻断的违规项
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Severity {
    Warning,
    Violation,
}

/// main Codex 项目级 Hook 入口
/// 核心职责：
/// - 从标准输入读取 PostToolUse 事件
/// - 检查本次工具触碰到的代码文件
fn main() {
    let mut input = String::new();
    let _ = io::stdin().read_to_string(&mut input);
    let root = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
    let paths = extract_touched_paths(&input);

    if paths.is_empty() {
        return;
    }

    let mut findings = Vec::new();
    for path in paths {
        let absolute = if path.is_absolute() {
            path
        } else {
            root.join(path)
        };
        findings.extend(evaluate_file(&root, &absolute));
    }

    let violations: Vec<&Finding> = findings
        .iter()
        .filter(|finding| finding.severity == Severity::Violation)
        .collect();
    if violations.is_empty() {
        return;
    }

    println!("[{ERROR_CODE}] 项目目录与文件规则检查失败");
    println!("原因：本次 Codex 触碰的代码文件存在 {} 个阻断项。", violations.len());
    println!("依据：AGENTS.md 第 4 节目录与文件规则。");
    println!("修复方式：拆分文件职责、移动到明确职责目录，或在代码中给出明确拆分理由。");
    for violation in violations.iter().take(8) {
        println!(
            "- path={} rule={} reason={}",
            violation.path, violation.rule, violation.message
        );
    }
    if violations.len() > 8 {
        println!("- 其余 {} 个阻断项已省略。", violations.len() - 8);
    }
    std::process::exit(1);
}

/// extract_touched_paths 提取本次工具触碰路径
/// 核心职责：
/// - 支持 Write/Edit 类事件的 file_path 字段
/// - 支持 apply_patch 文本中的文件路径
fn extract_touched_paths(input: &str) -> Vec<PathBuf> {
    let mut paths = BTreeSet::new();

    for value in values_after_json_key(input, "file_path") {
        paths.insert(PathBuf::from(value));
    }

    for line in decoded_json_text(input).lines() {
        for marker in [
            "*** Add File: ",
            "*** Update File: ",
            "*** Delete File: ",
            "*** Move to: ",
        ] {
            if let Some(path) = line.strip_prefix(marker) {
                let trimmed = path.trim();
                if !trimmed.is_empty() {
                    paths.insert(PathBuf::from(trimmed));
                }
            }
        }
    }

    paths.into_iter().collect()
}

/// evaluate_file 检查单个代码文件
/// 核心职责：
/// - 执行 Swift 与 Rust 文件行数门禁
/// - 执行职责目录和单文件单职责基础检查
fn evaluate_file(repo_root: &Path, path: &Path) -> Vec<Finding> {
    let Some(extension) = path.extension().and_then(|value| value.to_str()) else {
        return Vec::new();
    };
    if extension != "swift" && extension != "rs" {
        return Vec::new();
    }
    if !path.exists() {
        return Vec::new();
    }

    let display_path = display_path(repo_root, path);
    let content = match fs::read_to_string(path) {
        Ok(content) => content,
        Err(error) => {
            return vec![Finding {
                path: display_path,
                rule: "file_unreadable",
                severity: Severity::Violation,
                message: format!("无法读取文件内容：{error}"),
            }];
        }
    };

    let mut findings = Vec::new();
    let line_count = content.lines().count();
    match extension {
        "swift" => add_line_limit_findings(
            &mut findings,
            &display_path,
            line_count,
            SWIFT_GUIDELINE_LIMIT,
            SWIFT_HARD_LIMIT,
            "swift_file_should_split",
            "swift_file_too_large",
            "Swift",
        ),
        "rs" => add_line_limit_findings(
            &mut findings,
            &display_path,
            line_count,
            RUST_GUIDELINE_LIMIT,
            RUST_HARD_LIMIT,
            "rust_file_should_split",
            "rust_file_too_large",
            "Rust",
        ),
        _ => {}
    }

    if !has_responsibility_directory(repo_root, path) {
        findings.push(Finding {
            path: display_path.clone(),
            rule: "missing_responsibility_directory",
            severity: Severity::Violation,
            message: format!(
                "代码文件未落在明确职责目录中；允许职责目录：{}",
                RESPONSIBILITY_DIRS.join(", ")
            ),
        });
    }

    let declarations = primary_declarations(extension, &content);
    if declarations.len() > 1 {
        findings.push(Finding {
            path: display_path,
            rule: "multiple_primary_types",
            severity: Severity::Violation,
            message: format!(
                "一个文件包含多个顶层主要类型：{}；一个类型优先一个文件。",
                declarations.join(", ")
            ),
        });
    }

    findings
}

/// add_line_limit_findings 添加行数检查结果
/// 核心职责：
/// - 区分建议阈值和硬阻断阈值
/// - 生成面向 Codex 的修复说明
fn add_line_limit_findings(
    findings: &mut Vec<Finding>,
    path: &str,
    line_count: usize,
    guideline_limit: usize,
    hard_limit: usize,
    warning_rule: &'static str,
    violation_rule: &'static str,
    language: &str,
) {
    if line_count > hard_limit {
        findings.push(Finding {
            path: path.to_owned(),
            rule: violation_rule,
            severity: Severity::Violation,
            message: format!(
                "{language} 文件 {line_count} 行，超过硬上限 {hard_limit} 行，必须拆分或给出明确理由。"
            ),
        });
    } else if line_count > guideline_limit {
        findings.push(Finding {
            path: path.to_owned(),
            rule: warning_rule,
            severity: Severity::Warning,
            message: format!(
                "{language} 文件 {line_count} 行，超过建议线 {guideline_limit} 行，后续应优先拆分。"
            ),
        });
    }
}

/// has_responsibility_directory 判断路径是否包含职责目录
/// 核心职责：
/// - 约束新代码进入明确架构职责目录
/// - 允许测试文件和配置入口采用既有目录形态
fn has_responsibility_directory(repo_root: &Path, path: &Path) -> bool {
    let relative = path.strip_prefix(repo_root).unwrap_or(path);
    let parts: Vec<String> = relative
        .components()
        .map(|component| component.as_os_str().to_string_lossy().to_string())
        .collect();

    if parts.iter().any(|part| {
        matches!(
            part.as_str(),
            "Tests" | "tests" | "__tests__" | "Fixtures" | "fixtures" | ".codex"
        )
    }) {
        return true;
    }

    parts
        .iter()
        .take(parts.len().saturating_sub(1))
        .any(|part| RESPONSIBILITY_DIRS.contains(&part.as_str()))
}

/// primary_declarations 提取顶层主要类型
/// 核心职责：
/// - 识别 Swift 顶层类型声明
/// - 识别 Rust 公开顶层类型与函数声明
fn primary_declarations(extension: &str, content: &str) -> Vec<String> {
    let mut declarations = Vec::new();
    for line in content.lines() {
        if line.starts_with(char::is_whitespace) {
            continue;
        }
        let line = line.trim_start();
        let declaration = match extension {
            "swift" => swift_declaration_name(line),
            "rs" => rust_declaration_name(line),
            _ => None,
        };
        if let Some(name) = declaration {
            if !declarations.contains(&name) {
                declarations.push(name);
            }
        }
    }
    declarations
}

/// swift_declaration_name 提取 Swift 类型名
/// 核心职责：
/// - 支持常见访问控制与修饰符
/// - 返回顶层主要声明名称
fn swift_declaration_name(line: &str) -> Option<String> {
    declaration_name_after_keywords(
        line,
        &["public", "open", "internal", "private", "fileprivate", "final"],
        &["struct", "class", "enum", "actor", "protocol"],
    )
}

/// rust_declaration_name 提取 Rust 公开声明名
/// 核心职责：
/// - 支持 pub 与 pub(crate) 公开声明
/// - 返回顶层主要声明名称
fn rust_declaration_name(line: &str) -> Option<String> {
    let mut rest = line.trim_start();
    if let Some(next) = rest.strip_prefix("pub ") {
        rest = next.trim_start();
    } else if rest.starts_with("pub(") {
        let end = rest.find(')')?;
        rest = rest[end + 1..].trim_start();
    } else {
        return None;
    }
    declaration_name_after_keywords(rest, &["async"], &["struct", "enum", "trait", "type", "fn"])
}

/// declaration_name_after_keywords 提取关键字后的标识符
/// 核心职责：
/// - 跳过声明修饰符
/// - 返回类型或函数名称
fn declaration_name_after_keywords(
    line: &str,
    modifiers: &[&str],
    keywords: &[&str],
) -> Option<String> {
    let words: Vec<&str> = line.split_whitespace().collect();
    let mut index = 0;
    while index < words.len() && modifiers.contains(&words[index]) {
        index += 1;
    }
    if index >= words.len() || !keywords.contains(&words[index]) {
        return None;
    }
    words
        .get(index + 1)
        .map(|value| trim_identifier(value))
        .filter(|value| !value.is_empty())
}

/// trim_identifier 清理声明标识符
/// 核心职责：
/// - 去除泛型、参数和标点
/// - 保留可读类型名称
fn trim_identifier(value: &str) -> String {
    value
        .chars()
        .take_while(|ch| ch.is_ascii_alphanumeric() || *ch == '_')
        .collect()
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
        while input.as_bytes().get(cursor).is_some_and(u8::is_ascii_whitespace) {
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

/// display_path 生成仓库相对路径
/// 核心职责：
/// - 优先展示仓库相对路径
/// - 在路径不属于仓库时保留原路径
fn display_path(repo_root: &Path, path: &Path) -> String {
    path.strip_prefix(repo_root)
        .unwrap_or(path)
        .to_string_lossy()
        .replace('\\', "/")
}

#[cfg(test)]
#[path = "maohuoban_project_rules_tests.rs"]
mod tests;
