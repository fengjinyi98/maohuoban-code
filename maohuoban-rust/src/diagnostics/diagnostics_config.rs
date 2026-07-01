use std::{path::PathBuf, time::Duration};

use maohuoban_diagnostics::{CleanupPolicy, DiagnosticsBootstrapConfig};

use super::{
    DEFAULT_CLEANUP_MAX_EXPORT_AGE_HOURS, DEFAULT_CLEANUP_MAX_SEGMENT_AGE_HOURS,
    DEFAULT_CLEANUP_MAX_TOTAL_BYTES, DEFAULT_INGEST_TOKEN, DEFAULT_MAX_BODY_BYTES,
    backend_privacy_policy, cleanup_interval_from_value, parse_u64_or,
};
use crate::diagnostics::DiagnosticsIngestConfig;

/// `backend_diagnostics_bootstrap_config` 构建后端 SDK 启动配置
/// 核心职责：
/// - 读取本地环境变量覆盖项
/// - 默认写入 workspace `.maohuoban-diagnostics/segments`
#[must_use]
pub fn backend_diagnostics_bootstrap_config() -> DiagnosticsBootstrapConfig {
    let segments_directory = diagnostics_segments_directory_from_env();
    let mut config = DiagnosticsBootstrapConfig::new("maohuoban-rust", "local", segments_directory);
    config.privacy = backend_privacy_policy();
    config.capture.max_message_length = 16 * 1024;
    config.capture.max_metadata_value_length = 1024;
    config.cleanup = cleanup_policy_from_env();
    config
}

/// `cleanup_policy_from_env` 读取本地诊断清理策略
/// 核心职责：
/// - 为 LLM 排障保留较短的默认事件窗口
/// - 支持本地环境变量临时放宽或收紧清理阈值
#[must_use]
pub fn cleanup_policy_from_env() -> CleanupPolicy {
    cleanup_policy_from_env_values(
        std::env::var("MAOHUOBAN_DIAGNOSTICS_MAX_TOTAL_BYTES")
            .ok()
            .as_deref(),
        std::env::var("MAOHUOBAN_DIAGNOSTICS_MAX_SEGMENT_AGE_HOURS")
            .ok()
            .as_deref(),
        std::env::var("MAOHUOBAN_DIAGNOSTICS_MAX_EXPORT_AGE_HOURS")
            .ok()
            .as_deref(),
    )
}

/// `cleanup_policy_from_env_values` 从环境变量值构造清理策略
/// 核心职责：
/// - 固化本地开发默认保留窗口
/// - 让测试不需要修改真实进程环境
#[must_use]
pub fn cleanup_policy_from_env_values(
    max_total_bytes: Option<&str>,
    max_segment_age_hours: Option<&str>,
    max_export_age_hours: Option<&str>,
) -> CleanupPolicy {
    CleanupPolicy {
        max_total_bytes: parse_u64_or(max_total_bytes, DEFAULT_CLEANUP_MAX_TOTAL_BYTES),
        max_segment_age: Duration::from_hours(parse_u64_or(
            max_segment_age_hours,
            DEFAULT_CLEANUP_MAX_SEGMENT_AGE_HOURS,
        )),
        max_export_age: Duration::from_hours(parse_u64_or(
            max_export_age_hours,
            DEFAULT_CLEANUP_MAX_EXPORT_AGE_HOURS,
        )),
    }
}

/// `cleanup_interval_from_env` 读取周期清理间隔
/// 核心职责：
/// - 控制长时间开发时的 segments 后台收敛频率
/// - 保留环境变量覆盖入口
#[must_use]
pub fn cleanup_interval_from_env() -> Duration {
    cleanup_interval_from_env_value(
        std::env::var("MAOHUOBAN_DIAGNOSTICS_CLEANUP_INTERVAL_MINS")
            .ok()
            .as_deref(),
    )
}

/// `cleanup_interval_from_env_value` 从环境变量值读取周期清理间隔
/// 核心职责：
/// - 提供测试友好的纯函数入口
/// - 避免非法值关闭默认清理
#[must_use]
pub fn cleanup_interval_from_env_value(value: Option<&str>) -> Duration {
    cleanup_interval_from_value(value)
}

/// `diagnostics_segments_directory_from_env` 读取诊断段文件目录
/// 核心职责：
/// - 支持环境变量覆盖 workspace segments 位置
/// - 为后端 SDK 和 Debug ingest 使用同一默认目录
#[must_use]
pub fn diagnostics_segments_directory_from_env() -> PathBuf {
    std::env::var("MAOHUOBAN_DIAGNOSTICS_SEGMENTS_DIR").map_or_else(
        |_| PathBuf::from(".maohuoban-diagnostics/segments"),
        PathBuf::from,
    )
}

/// `diagnostics_ingest_config_from_env` 读取 Debug ingest 配置
/// 核心职责：
/// - 支持本地环境变量开启和鉴权 token 覆盖
/// - 约束真机回流写入 workspace 段文件
#[must_use]
pub fn diagnostics_ingest_config_from_env() -> DiagnosticsIngestConfig {
    DiagnosticsIngestConfig {
        segments_directory: diagnostics_segments_directory_from_env(),
        token: std::env::var("MAOHUOBAN_DIAGNOSTICS_INGEST_TOKEN")
            .unwrap_or_else(|_| DEFAULT_INGEST_TOKEN.to_owned()),
        max_body_bytes: std::env::var("MAOHUOBAN_DIAGNOSTICS_INGEST_MAX_BODY_BYTES")
            .ok()
            .and_then(|value| value.parse().ok())
            .unwrap_or(DEFAULT_MAX_BODY_BYTES),
    }
}
