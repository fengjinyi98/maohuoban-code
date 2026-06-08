use maohuoban_diagnostics::{
    CleanupPolicy, DiagnosticEvent, Diagnostics, DiagnosticsConfig, EventKind, FileSegmentStore,
    PrivacyPolicy, Severity,
};

/// main 毛伙伴 Rust 产品入口
/// 核心职责：
/// - 演示产品侧一次安装诊断 SDK
/// - 记录产品进程生命周期事件
fn main() {
    let diagnostics = install_diagnostics();
    diagnostics.record(DiagnosticEvent::new(
        EventKind::Lifecycle,
        Severity::Info,
        "maohuoban rust started",
    ));
    let _ = diagnostics.flush();
}

fn install_diagnostics() -> Diagnostics {
    let store = FileSegmentStore::new("target/maohuoban-diagnostics/segments", 1024 * 1024)
        .expect("create diagnostics store");
    Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "local".to_string(),
        privacy: PrivacyPolicy::default()
            .redact_key("authorization")
            .redact_key("password"),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics")
}
