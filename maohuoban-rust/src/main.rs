use maohuoban_diagnostics::{DiagnosticEvent, Diagnostics, EventKind, Severity};
use maohuoban_rust::{
    BackendConfig, agent_followup_planner, agent_followup_scheduler, build_backend_app,
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
    let planner_config = agent_followup_planner::AgentFollowupPlannerConfig {
        ai_llm_provider_config: config.ai_llm_provider_config.clone(),
        runtime_engine_mode: config.ai_runtime_engine_mode,
    };
    let app = build_backend_app(config).await?;
    let _agent_followup_planner_task =
        spawn_agent_followup_planner(planner_config, app.pool.clone());
    let _agent_followup_scheduler_task =
        spawn_agent_followup_scheduler(app.pool.clone(), app.home_realtime_hub.clone());
    let listener = tokio::net::TcpListener::bind(&server_bind_addr).await?;
    tracing::info!(bind_addr = %server_bind_addr, "毛伙伴 Rust 服务已监听");
    axum::serve(listener, app.router).await?;
    diagnostics.flush()?;
    Ok(())
}

/// `spawn_agent_followup_planner` 启动 Agent 主动追踪动态规划
/// 核心职责：
/// - 周期扫描待规划 abnormal followup plan
/// - 使用 Agent Runtime 生成追踪时间和站内轻提醒文案
fn spawn_agent_followup_planner(
    config: agent_followup_planner::AgentFollowupPlannerConfig,
    pool: sqlx::PgPool,
) -> tokio::task::JoinHandle<()> {
    let interval_duration = agent_followup_planner_interval_from_env();
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(interval_duration);
        interval.tick().await;
        loop {
            interval.tick().await;
            match agent_followup_planner::run_once(config.clone(), pool.clone(), chrono::Utc::now())
                .await
            {
                Ok(result) if result.planned_count > 0 => {
                    tracing::info!(
                        planned_count = result.planned_count,
                        "Agent 主动追踪动态规划完成"
                    );
                }
                Ok(_) => {}
                Err(error) => {
                    tracing::warn!(error = %error, "Agent 主动追踪动态规划失败");
                }
            }
        }
    })
}

/// `spawn_agent_followup_scheduler` 启动 Agent 主动追踪站内提醒调度
/// 核心职责：
/// - 周期扫描到期 abnormal followup plan
/// - 将到期计划投影为首页轻提醒
fn spawn_agent_followup_scheduler(
    pool: sqlx::PgPool,
    realtime_hub: maohuoban_home_http::home::HomeRealtimeHub,
) -> tokio::task::JoinHandle<()> {
    let interval_duration = agent_followup_scheduler_interval_from_env();
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(interval_duration);
        interval.tick().await;
        loop {
            interval.tick().await;
            match agent_followup_scheduler::run_once(&pool, chrono::Utc::now(), &realtime_hub).await
            {
                Ok(result) if result.projected_hints > 0 => {
                    tracing::info!(
                        projected_hints = result.projected_hints,
                        proactive_messages = result.proactive_messages,
                        "Agent 主动追踪轻提醒投影完成"
                    );
                }
                Ok(_) => {}
                Err(error) => {
                    tracing::warn!(error = %error, "Agent 主动追踪调度失败");
                }
            }
        }
    })
}

/// `agent_followup_planner_interval_from_env` 读取 Agent 动态规划间隔
/// 核心职责：
/// - 支持本地和部署环境调整规划扫描频率
/// - 对无效环境变量回退到默认 60 秒
fn agent_followup_planner_interval_from_env() -> std::time::Duration {
    std::env::var("MAOHUOBAN_AGENT_FOLLOWUP_PLANNER_INTERVAL_SECONDS")
        .ok()
        .and_then(|value| value.parse::<u64>().ok())
        .filter(|seconds| *seconds > 0)
        .map_or_else(
            || std::time::Duration::from_mins(1),
            std::time::Duration::from_secs,
        )
}

/// `agent_followup_scheduler_interval_from_env` 读取 Agent 主动追踪调度间隔
/// 核心职责：
/// - 支持本地和部署环境调整扫描频率
/// - 对无效环境变量回退到默认 60 秒
fn agent_followup_scheduler_interval_from_env() -> std::time::Duration {
    std::env::var("MAOHUOBAN_AGENT_FOLLOWUP_SCHEDULER_INTERVAL_SECONDS")
        .ok()
        .and_then(|value| value.parse::<u64>().ok())
        .filter(|seconds| *seconds > 0)
        .map_or_else(
            || std::time::Duration::from_mins(1),
            std::time::Duration::from_secs,
        )
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
