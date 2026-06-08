use crate::{CapturePolicy, CleanupPolicy, EventStore, PrivacyPolicy};
use std::{
    path::PathBuf,
    sync::{Arc, Mutex, OnceLock},
    time::Instant,
};

mod capture_api;
mod config;
mod context;
mod context_api;
mod health;
mod helpers;
mod lifecycle;
mod storage_api;

pub use config::{DiagnosticsBootstrapConfig, DiagnosticsConfig};
pub(crate) use helpers::event_with_metadata;

use context::DiagnosticsContext;
use health::DiagnosticsStorageHealth;
use helpers::{TraceScopeGuard, directory_size, panic_message, process_name, unique_paths};

/// `Diagnostics` 诊断 SDK 主入口
/// 核心职责：
/// - 持有一次安装后的共享运行时状态
/// - 将生命周期、上下文、采集、存储和导出能力委托给职责模块
#[derive(Clone)]
pub struct Diagnostics {
    inner: Arc<DiagnosticsInner>,
}

struct DiagnosticsInner {
    service_name: String,
    environment: String,
    privacy: PrivacyPolicy,
    capture: CapturePolicy,
    cleanup: CleanupPolicy,
    started_at: Instant,
    context: Mutex<DiagnosticsContext>,
    storage_health: Mutex<DiagnosticsStorageHealth>,
    store: Mutex<Box<dyn EventStore>>,
    export_directories: Mutex<Vec<PathBuf>>,
    export_index_path: Option<PathBuf>,
}

impl Diagnostics {
    fn new(inner: DiagnosticsInner) -> Self {
        Self {
            inner: Arc::new(inner),
        }
    }
}

static CURRENT_DIAGNOSTICS: OnceLock<Mutex<Option<Diagnostics>>> = OnceLock::new();
