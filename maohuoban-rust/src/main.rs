use maohuoban_diagnostics::{
    DiagnosticEvent, Diagnostics, DiagnosticsBootstrapConfig, EventKind, PrivacyPolicy, Severity,
};
use maohuoban_rust::{BackendConfig, build_backend_app};

/// main 毛伙伴 Rust 产品入口
/// 核心职责：
/// - 初始化诊断 SDK 和后端 HTTP 服务
/// - 启动认证接口运行时
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let diagnostics = install_diagnostics();
    diagnostics.record(DiagnosticEvent::new(
        EventKind::Lifecycle,
        Severity::Info,
        "maohuoban rust started",
    ));
    let config = BackendConfig::from_env();
    let server_bind_addr = config.server_bind_addr.clone();
    let app = build_backend_app(config).await?;
    let listener = tokio::net::TcpListener::bind(&server_bind_addr).await?;
    axum::serve(listener, app.router).await?;
    diagnostics.flush()?;
    Ok(())
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
