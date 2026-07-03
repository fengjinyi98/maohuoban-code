use std::path::Path;

use super::super::config::RESPONSIBILITY_DIRS;

/// has_responsibility_directory 判断路径是否包含职责目录
/// 核心职责：
/// - 约束新代码进入明确架构职责目录
/// - 允许测试文件和配置入口采用既有目录形态
pub(super) fn has_responsibility_directory(repo_root: &Path, path: &Path) -> bool {
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

    if is_rust_workspace_layer_path(&parts) {
        return true;
    }

    parts
        .iter()
        .take(parts.len().saturating_sub(1))
        .any(|part| RESPONSIBILITY_DIRS.contains(&part.as_str()))
}

/// is_rust_workspace_layer_path 判断 Rust workspace 分层路径
/// 核心职责：
/// - 认可 crate 名中的 domain/application/infrastructure/http 分层
/// - 认可既有 Rust 模块目录中的职责命名
fn is_rust_workspace_layer_path(parts: &[String]) -> bool {
    let has_rust_workspace = parts.iter().any(|part| part == "maohuoban-rust");
    if !has_rust_workspace {
        return false;
    }

    parts.iter().any(|part| {
        part.ends_with("-domain")
            || part.ends_with("-application")
            || part.ends_with("-infrastructure")
            || part.ends_with("-http")
            || matches!(
                part.as_str(),
                "domain"
                    | "application"
                    | "infrastructure"
                    | "http"
                    | "ports"
                    | "repository"
                    | "repositories"
                    | "router"
                    | "routes"
                    | "model"
                    | "models"
                    | "service"
                    | "services"
            )
    })
}

/// display_path 生成仓库相对路径
/// 核心职责：
/// - 优先展示仓库相对路径
/// - 在路径不属于仓库时保留原路径
pub(super) fn display_path(repo_root: &Path, path: &Path) -> String {
    path.strip_prefix(repo_root)
        .unwrap_or(path)
        .to_string_lossy()
        .replace('\\', "/")
}
