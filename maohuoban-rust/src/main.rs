use maohuoban_diagnostics::{
    DiagnosticEvent, Diagnostics, DiagnosticsBootstrapConfig, EventKind, PrivacyPolicy, Severity,
};

/// main 毛伙伴 Rust 产品入口
/// 核心职责：
/// - 演示产品侧一次 bootstrap 接入诊断 SDK
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

/// `install_diagnostics` 初始化诊断 SDK
/// 核心职责：
/// - 汇总产品侧启动配置
/// - 通过 SDK bootstrap 完成全局诊断运行时安装
fn install_diagnostics() -> Diagnostics {
    let mut config = DiagnosticsBootstrapConfig::new(
        "maohuoban-rust",
        "local",
        "target/maohuoban-diagnostics/segments",
    );
    config.privacy = PrivacyPolicy::default()
        .redact_key("authorization")
        .redact_key("password");
    Diagnostics::bootstrap(config).expect("bootstrap diagnostics")
}
