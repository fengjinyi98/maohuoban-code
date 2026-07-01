//! helpers 辅助函数与常量
//! 核心职责：
//! - 测试用 tool_call_response、find_tool_message 等工厂函数
//! - 共享的 AUTHORIZED_PET_ID 常量

use std::sync::{Arc, Mutex};

use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolGatewayObserver, ToolGatewayExecutionContext,
};
use maohuoban_ai_domain::ai::{
    LlmChatResponse, LlmFinishReason, LlmMessage, LlmRole, LlmToolCall, LlmUsage,
    ToolExecutionAudit,
};
use uuid::Uuid;

pub(super) const AUTHORIZED_PET_ID: &str = "11111111-1111-1111-1111-111111111111";

/// `tool_call_response` 构造包含工具调用的脚本响应
pub(super) fn tool_call_response(tool_name: &str, args: serde_json::Value) -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: String::new(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![LlmToolCall {
            id: "call_1".to_owned(),
            name: tool_name.to_owned(),
            arguments: args.to_string(),
        }],
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::ToolCalls,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

/// `multi_tool_call_response` 构造包含多个工具调用的脚本响应
pub(super) fn multi_tool_call_response(tool_name: &str, count: usize) -> LlmChatResponse {
    let tool_calls = (0..count)
        .map(|i| LlmToolCall {
            id: format!("call_{i}"),
            name: tool_name.to_owned(),
            arguments: "{}".to_owned(),
        })
        .collect();
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: String::new(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls,
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::ToolCalls,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

/// `find_tool_message` 从请求列表中找到 followup 请求的 tool role 消息
pub(super) fn find_tool_message(
    requests: &[maohuoban_ai_domain::ai::LlmChatRequest],
) -> &LlmMessage {
    requests
        .iter()
        .find(|req| req.messages.iter().any(|m| m.role == LlmRole::Tool))
        .and_then(|req| req.messages.iter().find(|m| m.role == LlmRole::Tool))
        .expect("followup request should contain a tool message")
}

pub(super) fn test_tool_context(pet_id: Uuid) -> AiToolContext {
    AiToolContext {
        actor_user_id: Uuid::new_v4(),
        authorized_pet_id: pet_id,
        gateway_context: ToolGatewayExecutionContext::default(),
        gateway_observer: None,
    }
}

/// `CapturingGatewayObserver` 测试用 Gateway 审计观察者
pub(super) struct CapturingGatewayObserver {
    pub(super) audits: Arc<Mutex<Vec<ToolExecutionAudit>>>,
}

#[async_trait::async_trait]
impl AiToolGatewayObserver for CapturingGatewayObserver {
    async fn record(&self, audit: &ToolExecutionAudit) {
        self.audits.lock().expect("audits").push(audit.clone());
    }
}

pub(super) fn test_tool_context_with_audits(
    pet_id: Uuid,
    audits: Arc<Mutex<Vec<ToolExecutionAudit>>>,
) -> AiToolContext {
    AiToolContext {
        actor_user_id: Uuid::new_v4(),
        authorized_pet_id: pet_id,
        gateway_context: ToolGatewayExecutionContext::default(),
        gateway_observer: Some(Arc::new(CapturingGatewayObserver { audits })),
    }
}
