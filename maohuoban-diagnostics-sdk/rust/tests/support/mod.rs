#![allow(dead_code)]

use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, CleanupReport, DiagnosticEvent, Diagnostics, DiagnosticsConfig,
    DiagnosticsError, EventStore, FileSegmentStore, PrivacyPolicy,
};
use std::{
    path::Path,
    sync::{Mutex, MutexGuard},
};

static DIAGNOSTICS_TEST_LOCK: Mutex<()> = Mutex::new(());

/// `diagnostics_test_lock` 隔离全局诊断运行时测试
/// 核心职责：
/// - 避免并行 integration tests 互相覆盖 `Diagnostics::current()`
/// - 保持每个测试的文件存储和全局 runtime 生命周期一致
pub fn diagnostics_test_lock() -> MutexGuard<'static, ()> {
    DIAGNOSTICS_TEST_LOCK.lock().expect("diagnostics test lock")
}

/// `install_file_diagnostics` 创建标准文件存储测试运行时
/// 核心职责：
/// - 统一测试用 service、environment 和文件段目录
/// - 允许行为域测试按需替换隐私、采集和清理策略
pub fn install_file_diagnostics(root: &Path) -> Diagnostics {
    install_file_diagnostics_with(
        root,
        1024 * 1024,
        PrivacyPolicy::default(),
        CapturePolicy::default(),
        CleanupPolicy::default(),
    )
}

/// `install_file_diagnostics_with` 创建可定制策略的文件存储测试运行时
/// 核心职责：
/// - 为策略测试提供最小配置入口
/// - 避免每个测试重复拼装 `DiagnosticsConfig`
pub fn install_file_diagnostics_with(
    root: &Path,
    max_segment_bytes: u64,
    privacy: PrivacyPolicy,
    capture: CapturePolicy,
    cleanup: CleanupPolicy,
) -> Diagnostics {
    let store = FileSegmentStore::new(root.join("segments"), max_segment_bytes).expect("store");
    Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy,
        capture,
        cleanup,
        store: Box::new(store),
    })
    .expect("install diagnostics")
}

/// `tar_entries` 解析测试用无压缩 tar 条目
/// 核心职责：
/// - 验证 Debug Bundle 归档可以按 tar 格式读取
/// - 对比归档内文件内容和导出目录原文件
pub fn tar_entries(archive: &[u8]) -> Vec<(String, Vec<u8>)> {
    let mut entries = Vec::new();
    let mut offset = 0;
    while offset + 512 <= archive.len() {
        let header = &archive[offset..offset + 512];
        if header.iter().all(|byte| *byte == 0) {
            break;
        }
        let name_end = header[0..100]
            .iter()
            .position(|byte| *byte == 0)
            .unwrap_or(100);
        let name = String::from_utf8(header[0..name_end].to_vec()).expect("tar name");
        let size_bytes = header[124..136]
            .iter()
            .copied()
            .filter(|byte| *byte != 0 && *byte != b' ')
            .collect::<Vec<_>>();
        let size_text = String::from_utf8(size_bytes).expect("tar size");
        let size = usize::from_str_radix(size_text.trim(), 8).expect("tar octal size");
        let data_start = offset + 512;
        let data_end = data_start + size;
        assert!(data_end <= archive.len(), "tar entry exceeds archive size");
        entries.push((name, archive[data_start..data_end].to_vec()));
        offset = data_start + size.div_ceil(512) * 512;
    }
    entries
}

#[derive(Debug, thiserror::Error)]
#[error("database unavailable")]
pub struct DatabaseError;

#[derive(Debug, thiserror::Error)]
#[error("checkout failed")]
pub struct CheckoutError {
    #[source]
    pub source: DatabaseError,
}

/// `FlakyStore` 测试用可失败存储
/// 核心职责：
/// - 模拟首次事件落盘失败
/// - 在后续写入中保留事件，验证运行时健康字段
pub struct FlakyStore {
    fail_next_append: bool,
    events: Vec<DiagnosticEvent>,
}

impl FlakyStore {
    pub fn fail_first_append() -> Self {
        Self {
            fail_next_append: true,
            events: Vec::new(),
        }
    }
}

impl EventStore for FlakyStore {
    fn append(&mut self, event: &DiagnosticEvent) -> Result<(), DiagnosticsError> {
        if self.fail_next_append {
            self.fail_next_append = false;
            return Err(std::io::Error::other("injected append failure").into());
        }
        self.events.push(event.clone());
        Ok(())
    }

    fn flush(&mut self) -> Result<(), DiagnosticsError> {
        Ok(())
    }

    fn read_all(&self) -> Result<Vec<DiagnosticEvent>, DiagnosticsError> {
        Ok(self.events.clone())
    }

    fn cleanup(&mut self, _policy: &CleanupPolicy) -> Result<CleanupReport, DiagnosticsError> {
        Ok(CleanupReport::default())
    }
}
