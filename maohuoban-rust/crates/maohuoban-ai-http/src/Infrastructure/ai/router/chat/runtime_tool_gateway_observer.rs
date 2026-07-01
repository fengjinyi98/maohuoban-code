use async_trait::async_trait;
use maohuoban_ai_application::ai::diagnostics::AiDiagnosticsCorrelation;
use maohuoban_ai_application::ai::diagnostics::redact_ai_diagnostics_value;
use maohuoban_ai_application::ai::tools::AiToolGatewayObserver;
use maohuoban_ai_domain::ai::ToolExecutionAudit;
use serde_json::json;

use super::super::diagnostics_common::{record_ai_event, severity};

/// RuntimeToolGatewayObserver Runtime Tool Gateway 诊断观察者
/// 核心职责：
/// - 将 Tool Gateway 审计统一写入正式 diagnostics 链路
/// - 固定 turn/message/session 关联键与工具审计字段
pub(super) struct RuntimeToolGatewayObserver;

#[async_trait]
impl AiToolGatewayObserver for RuntimeToolGatewayObserver {
    async fn record(&self, audit: &ToolExecutionAudit) {
        let mut metadata = AiDiagnosticsCorrelation {
            session_id: audit.session_id,
            turn_id: audit.turn_id,
            message_id: audit.message_id,
            tool_call_id: None,
            provider: None,
            model: None,
        }
        .to_metadata();
        metadata.extend(vec![
            (
                "session_id",
                json!(audit.session_id.map(|id| id.to_string())),
            ),
            ("turn_id", json!(audit.turn_id.map(|id| id.to_string()))),
            (
                "message_id",
                json!(audit.message_id.map(|id| id.to_string())),
            ),
            ("tool_name", json!(audit.tool_name)),
            ("args", redact_ai_diagnostics_value(&audit.args)),
            ("policy_decision", json!(audit.policy_decision)),
            ("duration_ms", json!(audit.duration_ms)),
            ("fact_count", json!(audit.fact_count)),
            ("citation_ids", json!(audit.citation_ids)),
            ("failure_code", json!(audit.failure_code)),
            ("risk_level", json!(audit.risk_level)),
            ("toolset", json!(audit.toolset)),
        ]);
        record_ai_event(
            "ai.chat.tool_gateway.completed",
            severity(audit.policy_decision == "success"),
            metadata,
        );
    }
}
