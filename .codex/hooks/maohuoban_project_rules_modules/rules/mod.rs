mod declarations;
mod paths;

use std::fs;
use std::path::Path;

use self::declarations::primary_declarations;
use self::paths::{display_path, has_responsibility_directory};
use super::config::{
    RESPONSIBILITY_DIRS, RUST_GUIDELINE_LIMIT, RUST_HARD_LIMIT, SWIFT_GUIDELINE_LIMIT,
    SWIFT_HARD_LIMIT,
};
use super::shared::{ChangeKind, Finding, Severity};

/// evaluate_file 检查单个代码文件
/// 核心职责：
/// - 执行 Swift 与 Rust 文件行数门禁
/// - 执行职责目录和单文件单职责基础检查
pub(crate) fn evaluate_file(
    repo_root: &Path,
    path: &Path,
    change_kind: ChangeKind,
) -> Vec<Finding> {
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

    if has_structure_exemption_reason(&content) {
        return Vec::new();
    }

    let mut findings = Vec::new();
    let strict = change_kind == ChangeKind::Added;
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
            strict,
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
            strict,
        ),
        _ => {}
    }

    if !has_responsibility_directory(repo_root, path) {
        findings.push(Finding {
            path: display_path.clone(),
            rule: "missing_responsibility_directory",
            severity: strict_severity(strict),
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
            severity: strict_severity(strict),
            message: format!(
                "一个文件包含多个顶层主要类型：{}；一个类型优先一个文件。",
                declarations.join(", ")
            ),
        });
    }

    findings
}

/// strict_severity 生成当前变更强度下的严重程度
/// 核心职责：
/// - 新增文件保持阻断
/// - 更新既有文件降级为提示
fn strict_severity(strict: bool) -> Severity {
    if strict {
        Severity::Violation
    } else {
        Severity::Warning
    }
}

/// has_structure_exemption_reason 判断是否存在明确结构豁免理由
/// 核心职责：
/// - 支持 AGENTS 中“给出明确理由”的例外路径
/// - 要求理由文本非空，避免空标记绕过门禁
fn has_structure_exemption_reason(content: &str) -> bool {
    content
        .lines()
        .take(12)
        .filter_map(|line| line.split_once("MHB_STRUCTURE_EXEMPTION:"))
        .any(|(_, reason)| !reason.trim().is_empty())
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
    strict: bool,
) {
    if line_count > hard_limit {
        findings.push(Finding {
            path: path.to_owned(),
            rule: violation_rule,
            severity: strict_severity(strict),
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
