use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, Diagnostics, DiagnosticsConfig, FileSegmentStore, PrivacyPolicy,
};
use uuid::Uuid;

/// `install_test_diagnostics` 安装规划测试诊断存储
/// 核心职责：
/// - 为规划诊断测试提供独立临时目录
/// - 返回可 flush/read 的 Diagnostics 实例
pub fn install_test_diagnostics() -> Diagnostics {
    let root = std::env::temp_dir().join(format!(
        "maohuoban-planning-runtime-diagnostics-{}",
        Uuid::new_v4()
    ));
    let store = FileSegmentStore::new(root.join("segments"), 1024 * 1024).expect("store");
    Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_owned(),
        environment: "test".to_owned(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics")
}
