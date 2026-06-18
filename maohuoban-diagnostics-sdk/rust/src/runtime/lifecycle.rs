use crate::{
    DiagnosticEvent, DiagnosticsError, EventKind, FileSegmentStore, QueuedEventStore,
    QueuedEventStoreConfig, Severity,
};
use serde_json::json;
use std::{sync::Mutex, time::Instant};

use super::{
    CURRENT_DIAGNOSTICS, Diagnostics, DiagnosticsBootstrapConfig, DiagnosticsConfig,
    DiagnosticsContext, DiagnosticsInner, DiagnosticsStorageHealth,
};

impl Diagnostics {
    /// `install` 安装诊断 SDK
    /// 核心职责：
    /// - 通过声明式配置创建可克隆 SDK 句柄
    /// - 将后续所有采集能力统一纳入同一管线
    ///
    /// # Errors
    ///
    /// 当前安装过程只封装配置与存储句柄，保留错误返回用于未来校验配置和存储初始化失败。
    pub fn install(config: DiagnosticsConfig) -> Result<Self, DiagnosticsError> {
        let export_index_path = config.store.export_index_path();
        let diagnostics = Self::new(DiagnosticsInner {
            service_name: config.service_name,
            environment: config.environment,
            privacy: config.privacy,
            capture: Mutex::new(config.capture),
            cleanup: config.cleanup,
            started_at: Instant::now(),
            context: Mutex::new(DiagnosticsContext::default()),
            storage_health: Mutex::new(DiagnosticsStorageHealth::default()),
            store: Mutex::new(config.store),
            export_directories: Mutex::new(Vec::new()),
            export_index_path,
        });
        let registry = CURRENT_DIAGNOSTICS.get_or_init(|| Mutex::new(None));
        if let Ok(mut current) = registry.lock() {
            *current = Some(diagnostics.clone());
        }
        Ok(diagnostics)
    }

    /// `bootstrap` 启动诊断 SDK
    /// 核心职责：
    /// - 初始化默认文件存储并完成全局安装
    /// - 注入启动上下文、记录生命周期事件和可选运行时快照
    ///
    /// # Errors
    ///
    /// 当文件存储初始化或启动清理失败时返回错误。
    pub fn bootstrap(config: DiagnosticsBootstrapConfig) -> Result<Self, DiagnosticsError> {
        let store = FileSegmentStore::new(&config.storage_directory, config.max_segment_bytes)?;
        let store = QueuedEventStore::new(Box::new(store), QueuedEventStoreConfig::default());
        let diagnostics = Self::install(DiagnosticsConfig {
            service_name: config.service_name,
            environment: config.environment,
            privacy: config.privacy,
            capture: config.capture,
            cleanup: config.cleanup,
            store: Box::new(store),
        })?;
        if config.cleanup_on_bootstrap {
            let _report = diagnostics.cleanup()?;
        }
        if let Some(session_id) = config.session_id {
            diagnostics.set_session_id(session_id);
        }
        if let Some(trace_id) = config.trace_id {
            diagnostics.set_trace_id(trace_id);
        }
        for (key, value) in config.defaults {
            diagnostics.set_context_metadata(key, value);
        }
        if config.install_panic_hook {
            diagnostics.install_panic_hook();
        }
        diagnostics.record(DiagnosticEvent::new(
            EventKind::Lifecycle,
            Severity::Info,
            "diagnostics bootstrap completed",
        ));
        if config.capture_runtime_snapshot {
            diagnostics.capture_runtime_snapshot([("phase", json!("bootstrap"))]);
        }
        Ok(diagnostics)
    }

    /// `current` 读取全局诊断句柄
    /// 核心职责：
    /// - 支持一次安装后任意模块读取同一运行时
    /// - 避免业务层传递临时诊断参数
    #[must_use]
    pub fn current() -> Option<Self> {
        CURRENT_DIAGNOSTICS
            .get()
            .and_then(|registry| registry.lock().ok().and_then(|current| current.clone()))
    }
}
