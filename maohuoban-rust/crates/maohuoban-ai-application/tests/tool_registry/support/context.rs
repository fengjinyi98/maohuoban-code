use async_trait::async_trait;
use maohuoban_ai_application::ai::ports::ObservationWriteContext;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolGatewayObserver, ToolGatewayExecutionContext,
};
use maohuoban_ai_domain::ai::ToolExecutionAudit;
use std::sync::{Arc, Mutex};
use uuid::Uuid;

/// `test_tool_context` 构造工具测试上下文
/// 核心职责：
/// - 固定当前授权宠物 ID
/// - 为工具注册表测试提供最小执行上下文
pub fn test_tool_context(pet_id: Uuid) -> AiToolContext {
    AiToolContext {
        actor_user_id: Uuid::new_v4(),
        observation_write_context: ObservationWriteContext::default(),
        authorized_pet_id: pet_id,
        gateway_context: ToolGatewayExecutionContext::default(),
        gateway_observer: None,
    }
}

/// `CapturingGatewayObserver` 测试用 Gateway 审计观察者
/// 核心职责：
/// - 收集 Tool Gateway 审计记录
/// - 让测试验证 Gateway 产出的正式审计字段
struct CapturingGatewayObserver {
    audits: Arc<Mutex<Vec<ToolExecutionAudit>>>,
}

#[async_trait]
impl AiToolGatewayObserver for CapturingGatewayObserver {
    async fn record(&self, audit: &ToolExecutionAudit) {
        self.audits.lock().expect("audits").push(audit.clone());
    }
}

/// `test_tool_context_with_audits` 构造带审计捕获器的工具上下文
/// 核心职责：
/// - 固定授权宠物 ID
/// - 注入捕获型 Gateway observer
pub fn test_tool_context_with_audits(
    pet_id: Uuid,
    audits: Arc<Mutex<Vec<ToolExecutionAudit>>>,
) -> AiToolContext {
    AiToolContext {
        actor_user_id: Uuid::new_v4(),
        observation_write_context: ObservationWriteContext::default(),
        authorized_pet_id: pet_id,
        gateway_context: ToolGatewayExecutionContext::default(),
        gateway_observer: Some(Arc::new(CapturingGatewayObserver { audits })),
    }
}
