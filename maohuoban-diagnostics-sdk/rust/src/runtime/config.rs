use crate::{CapturePolicy, CleanupPolicy, EventStore, PrivacyPolicy};
use serde_json::{Map, Value};
use std::path::PathBuf;

/// `DiagnosticsConfig` SDK 安装配置
/// 核心职责：
/// - 汇总服务名、环境、隐私、清理和存储依赖
/// - 作为一次全局安装入口的声明式配置
pub struct DiagnosticsConfig {
    pub service_name: String,
    pub environment: String,
    pub privacy: PrivacyPolicy,
    pub capture: CapturePolicy,
    pub cleanup: CleanupPolicy,
    pub store: Box<dyn EventStore>,
}

/// `DiagnosticsBootstrapConfig` SDK 启动接入配置
/// 核心职责：
/// - 将文件存储、隐私策略、清理策略和默认上下文汇总为一个声明式入口
/// - 为服务启动阶段提供一次调用即可全局可用的诊断管线
pub struct DiagnosticsBootstrapConfig {
    pub service_name: String,
    pub environment: String,
    pub storage_directory: PathBuf,
    pub max_segment_bytes: u64,
    pub privacy: PrivacyPolicy,
    pub capture: CapturePolicy,
    pub cleanup: CleanupPolicy,
    pub defaults: Map<String, Value>,
    pub session_id: Option<String>,
    pub trace_id: Option<String>,
    pub capture_runtime_snapshot: bool,
    pub cleanup_on_bootstrap: bool,
    pub install_panic_hook: bool,
}

impl DiagnosticsBootstrapConfig {
    /// `new` 创建启动接入配置
    /// 核心职责：
    /// - 提供最小必填字段入口
    /// - 为可选策略提供生产可用默认值
    #[must_use]
    pub fn new(
        service_name: impl Into<String>,
        environment: impl Into<String>,
        storage_directory: impl Into<PathBuf>,
    ) -> Self {
        Self {
            service_name: service_name.into(),
            environment: environment.into(),
            storage_directory: storage_directory.into(),
            max_segment_bytes: 1024 * 1024,
            privacy: PrivacyPolicy::default(),
            capture: CapturePolicy::default(),
            cleanup: CleanupPolicy::default(),
            defaults: Map::new(),
            session_id: None,
            trace_id: None,
            capture_runtime_snapshot: true,
            cleanup_on_bootstrap: true,
            install_panic_hook: true,
        }
    }
}
