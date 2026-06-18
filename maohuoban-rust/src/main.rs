use maohuoban_diagnostics::{DiagnosticEvent, Diagnostics, EventKind, Severity};
use maohuoban_rust::{
    BackendConfig, build_backend_app,
    diagnostics::{backend_diagnostics_bootstrap_config, cleanup_interval_from_env},
};

/// main 毛伙伴 Rust 产品入口
/// 核心职责：
/// - 初始化诊断 SDK 和后端 HTTP 服务
/// - 启动认证接口运行时
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    install_tracing();
    let diagnostics = install_diagnostics();
    let _cleanup_task = spawn_diagnostics_cleanup(diagnostics.clone());
    diagnostics.record(DiagnosticEvent::new(
        EventKind::Lifecycle,
        Severity::Info,
        "maohuoban rust started",
    ));
    let config = BackendConfig::from_env();
    let server_bind_addr = config.server_bind_addr.clone();
    let app = build_backend_app(config).await?;
    let listener = tokio::net::TcpListener::bind(&server_bind_addr).await?;
    tracing::info!(bind_addr = %server_bind_addr, "毛伙伴 Rust 服务已监听");
    axum::serve(listener, app.router).await?;
    diagnostics.flush()?;
    Ok(())
}

/// `install_tracing` 初始化终端日志
/// 核心职责：
/// - 为本地 cargo run 输出启动状态
/// - 让服务进入监听后有明确可见反馈
fn install_tracing() {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();
}

/// `install_diagnostics` 初始化诊断 SDK
/// 核心职责：
/// - 汇总产品侧启动配置
/// - 通过 SDK bootstrap 完成全局诊断运行时安装
fn install_diagnostics() -> Diagnostics {
    let config = backend_diagnostics_bootstrap_config();
    Diagnostics::bootstrap(config).expect("bootstrap diagnostics")
}

/// `spawn_diagnostics_cleanup` 启动诊断段文件周期清理
/// 核心职责：
/// - 长时间本地开发时自动收敛 workspace segments
/// - 将同步文件清理放入阻塞线程池执行
fn spawn_diagnostics_cleanup(diagnostics: Diagnostics) -> tokio::task::JoinHandle<()> {
    let interval_duration = cleanup_interval_from_env();
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(interval_duration);
        interval.tick().await;
        loop {
            interval.tick().await;
            let cleanup_diagnostics = diagnostics.clone();
            match tokio::task::spawn_blocking(move || cleanup_diagnostics.cleanup()).await {
                Ok(Ok(report)) if report.removed_segments > 0 || report.removed_exports > 0 => {
                    tracing::info!(
                        removed_segments = report.removed_segments,
                        removed_exports = report.removed_exports,
                        freed_bytes = report.freed_bytes,
                        "诊断报告清理完成"
                    );
                }
                Ok(Ok(_)) => {}
                Ok(Err(error)) => {
                    tracing::warn!(error = %error, "诊断报告清理失败");
                }
                Err(error) => {
                    tracing::warn!(error = %error, "诊断报告清理任务失败");
                }
            }
        }
    })
}
