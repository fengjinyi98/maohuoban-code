#[path = "maohuoban_project_rules_modules/mod.rs"]
mod project_rules;

use std::io::{self, Read};
use std::path::PathBuf;

use project_rules::config::{BLOCKING_EXIT_CODE, ERROR_CODE};
use project_rules::input::extract_touched_files;
#[cfg(test)]
use project_rules::input::extract_touched_paths;
use project_rules::rules::evaluate_file;
#[cfg(test)]
use project_rules::shared::ChangeKind;
use project_rules::shared::{Finding, Severity};

/// main Codex 项目级 Hook 入口
/// 核心职责：
/// - 从标准输入读取 PostToolUse 事件
/// - 检查本次工具触碰到的代码文件
fn main() {
    let mut input = String::new();
    let _ = io::stdin().read_to_string(&mut input);
    let root = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
    let paths = extract_touched_files(&input);

    if paths.is_empty() {
        return;
    }

    let mut findings = Vec::new();
    for touched_path in paths {
        let absolute = if touched_path.path.is_absolute() {
            touched_path.path
        } else {
            root.join(touched_path.path)
        };
        findings.extend(evaluate_file(&root, &absolute, touched_path.kind));
    }

    let violations: Vec<&Finding> = findings
        .iter()
        .filter(|finding| finding.severity == Severity::Violation)
        .collect();
    let warnings: Vec<&Finding> = findings
        .iter()
        .filter(|finding| finding.severity == Severity::Warning)
        .collect();
    if violations.is_empty() && warnings.is_empty() {
        return;
    }

    if !warnings.is_empty() {
        eprintln!("[{ERROR_CODE}] 项目目录与文件规则提示");
        eprintln!(
            "原因：本次 Codex 触碰的代码文件存在 {} 个提示项。",
            warnings.len()
        );
        for warning in warnings.iter().take(8) {
            eprintln!(
                "- path={} rule={} reason={}",
                warning.path, warning.rule, warning.message
            );
        }
        if warnings.len() > 8 {
            eprintln!("- 其余 {} 个提示项已省略。", warnings.len() - 8);
        }
    }

    if violations.is_empty() {
        return;
    }

    eprintln!("[{ERROR_CODE}] 项目目录与文件规则检查失败");
    eprintln!(
        "原因：本次 Codex 触碰的代码文件存在 {} 个阻断项。",
        violations.len()
    );
    eprintln!("依据：AGENTS.md 第 4 节目录与文件规则。");
    eprintln!("修复方式：拆分文件职责、移动到明确职责目录，或在代码中给出明确拆分理由。");
    for violation in violations.iter().take(8) {
        eprintln!(
            "- path={} rule={} reason={}",
            violation.path, violation.rule, violation.message
        );
    }
    if violations.len() > 8 {
        eprintln!("- 其余 {} 个阻断项已省略。", violations.len() - 8);
    }
    std::process::exit(BLOCKING_EXIT_CODE);
}

#[cfg(test)]
#[path = "maohuoban_project_rules_tests.rs"]
mod tests;
