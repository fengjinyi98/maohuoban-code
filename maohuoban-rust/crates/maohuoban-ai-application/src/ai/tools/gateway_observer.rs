use async_trait::async_trait;
use maohuoban_ai_domain::ai::ToolExecutionAudit;

/// AiToolGatewayObserver Tool Gateway 审计观察者
/// 核心职责：
/// - 接收统一审计记录并写入 diagnostics 或其他观测出口
/// - 保持 Gateway 不依赖具体 HTTP/基础设施实现
#[async_trait]
pub trait AiToolGatewayObserver: Send + Sync {
    async fn record(&self, audit: &ToolExecutionAudit);
}
