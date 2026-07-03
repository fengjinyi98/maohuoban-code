#[path = "gateway/confirmation_contract_tool.rs"]
mod confirmation_contract_tool;
#[path = "gateway/failed_contract_tool.rs"]
mod failed_contract_tool;

use async_trait::async_trait;
pub use confirmation_contract_tool::ConfirmationContractTool;
pub use failed_contract_tool::FailedContractTool;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolGatewayObserver, ToolGatewayExecutionContext,
};
use maohuoban_ai_domain::ai::ToolExecutionAudit;
use std::sync::{Arc, Mutex};
use uuid::Uuid;

/// `CapturingGatewayObserver` 捕获 Tool Gateway 审计事件
/// 核心职责：
/// - 收集工具执行审计记录
/// - 为合同测试提供可断言的审计快照
struct CapturingGatewayObserver {
    audits: Arc<Mutex<Vec<ToolExecutionAudit>>>,
}

#[async_trait]
impl AiToolGatewayObserver for CapturingGatewayObserver {
    async fn record(&self, audit: &ToolExecutionAudit) {
        self.audits.lock().expect("audits").push(audit.clone());
    }
}

/// `test_gateway_context_with_audits` 构造带审计捕获器的工具上下文
/// 核心职责：
/// - 固定测试 actor、pet、session、turn 和 message 标识
/// - 注入捕获型 Tool Gateway observer
pub fn test_gateway_context_with_audits(
    audits: Arc<Mutex<Vec<ToolExecutionAudit>>>,
) -> AiToolContext {
    AiToolContext {
        actor_user_id: Uuid::new_v4(),
        authorized_pet_id: Uuid::new_v4(),
        gateway_context: ToolGatewayExecutionContext {
            session_id: Some(Uuid::new_v4()),
            turn_id: Some(Uuid::new_v4()),
            message_id: Some(Uuid::new_v4()),
            confirmation_task_id: None,
        },
        gateway_observer: Some(Arc::new(CapturingGatewayObserver { audits })),
    }
}

/// `assert_recorded_audit` 断言捕获到的工具审计记录
/// 核心职责：
/// - 验证工具名、策略决策和失败码
/// - 验证会话、轮次和消息标识已记录
pub fn assert_recorded_audit(
    audits: &Arc<Mutex<Vec<ToolExecutionAudit>>>,
    tool_name: &str,
    policy_decision: &str,
    failure_code: Option<&str>,
) {
    let recorded = audits.lock().expect("audits");
    assert_eq!(recorded.len(), 1);
    assert_eq!(recorded[0].tool_name, tool_name);
    assert_eq!(recorded[0].policy_decision, policy_decision);
    assert_eq!(recorded[0].failure_code.as_deref(), failure_code);
    assert!(recorded[0].session_id.is_some());
    assert!(recorded[0].turn_id.is_some());
    assert!(recorded[0].message_id.is_some());
}
